class SentimentAnalysisJob < ApplicationJob
  queue_as :default

  WINDOW_SECONDS = 180

  def perform(meeting_id)
    meeting = Meeting.includes(:transcript).find(meeting_id)
    transcript = meeting.transcript
    unless transcript
      MeetingProcessingChannel.broadcast_to(meeting, { step: "sentiment", status: "completed" })
      MeetingPipeline.mark_sentiment!(meeting_id)
      return
    end

    MeetingProcessingChannel.broadcast_to(meeting, { step: "sentiment", status: "started" })

    segments = transcript.parsed_segments_normalized.reject { |s| s["text"].blank? }
    if segments.blank?
      MeetingProcessingChannel.broadcast_to(meeting, { step: "sentiment", status: "completed" })
      MeetingPipeline.mark_sentiment!(meeting_id)
      return
    end

    timeline = build_timeline(segments)
    per_speaker = build_per_speaker(segments)

    overall = if timeline.any?
      timeline.sum { |w| w["score"].to_f } / timeline.size
    elsif per_speaker.any?
      per_speaker.sum { |s| s["average_score"].to_f } / per_speaker.size
    else
      nil
    end

    payload = {
      "timeline" => timeline,
      "per_speaker" => per_speaker,
      "overall_score" => overall
    }

    meeting.update!(sentiment_data: payload, overall_sentiment_score: overall)

    Turbo::StreamsChannel.broadcast_replace_to(
      "meeting_#{meeting.id}",
      target: "sentiment-dashboard",
      partial: "meetings/sentiment_dashboard",
      locals: { meeting: meeting.reload }
    )

    MeetingProcessingChannel.broadcast_to(meeting, { step: "sentiment", status: "completed" })
    MeetingPipeline.mark_sentiment!(meeting_id)
  end

  private
    def build_timeline(segments)
      return [] if segments.blank?

      max_t = segments.map { |s| s["end_time"].to_i }.max
      windows = []
      start = 0
      while start <= max_t
        finish = start + WINDOW_SECONDS
        lines = segments.select { |s| s["start_time"].to_i < finish && s["end_time"].to_i > start }
        text = lines.map { |s| "#{s['speaker']}: #{s['text']}" }.join("\n")
        if text.present?
          begin
            res = HuggingFaceService.analyse_sentiment_window(text)
            windows << {
              "window_start" => start,
              "window_end" => finish,
              "score" => res["score"].to_f,
              "label" => res["label"],
              "dominant_emotion" => res["dominant_emotion"],
              "speakers" => Array(res["speakers"]),
              "transcript_snippet" => text
            }
          rescue HuggingFaceService::Error
            windows << {
              "window_start" => start,
              "window_end" => finish,
              "score" => 0.0,
              "label" => "discussion",
              "dominant_emotion" => "neutral",
              "speakers" => lines.map { |s| s["speaker"] }.uniq,
              "transcript_snippet" => text
            }
          end
        end
        start = finish
      end
      windows
    end

    def build_per_speaker(segments)
      by = segments.group_by { |s| s["speaker"].presence || "Speaker" }
      by.map do |name, segs|
        lines = segs.map { |s| "#{s['start_time']}s: #{s['text']}" }.join("\n")
        begin
          res = HuggingFaceService.analyse_speaker_sentiment(name, lines)
          {
            "name" => name,
            "average_score" => res["average_score"].to_f,
            "dominant_emotion" => res["dominant_emotion"],
            "segment_count" => res["segment_count"].to_i
          }
        rescue HuggingFaceService::Error
          {
            "name" => name,
            "average_score" => 0.0,
            "dominant_emotion" => "neutral",
            "segment_count" => segs.size
          }
        end
      end
    end
end
