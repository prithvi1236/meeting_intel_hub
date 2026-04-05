class ExtractItemsJob < ApplicationJob
  queue_as :default

  def perform(meeting_id)
    meeting = Meeting.includes(:project, :transcript_chunks).find(meeting_id)
    transcript = meeting.transcript
    unless transcript
      MeetingPipeline.mark_extract!(meeting_id)
      return
    end

    MeetingProcessingChannel.broadcast_to(meeting, { step: "extract", status: "started" })

    segments = transcript.parsed_segments
    text = segments.map { |s| "#{s['speaker']}: #{s['text']}" }.join("\n").truncate(48_000)

    data = GroqService.extract_items(text) do |chunk|
      MeetingProcessingChannel.broadcast_to(
        meeting,
        { step: "extract", status: "streaming", content: chunk }
      )
    end

    meeting.extracted_items.destroy_all
    pos = 0
    Array(data["decisions"]).each do |d|
      meeting.extracted_items.create!(
        item_type: :decision,
        description: d["description"],
        owner: nil,
        due_date: nil,
        confidence_score: d["confidence"],
        source_quote: d["source_quote"],
        source_timestamp: d["source_timestamp"],
        status: :open,
        position: (pos += 1)
      )
    end

    Array(data["action_items"]).each do |a|
      meeting.extracted_items.create!(
        item_type: :action_item,
        description: a["description"],
        owner: a["owner"].presence,
        due_date: parse_optional_due_date(a["due_date"]),
        confidence_score: a["confidence"],
        source_quote: a["source_quote"],
        source_timestamp: a["source_timestamp"],
        status: :open,
        position: (pos += 1)
      )
    end

    Turbo::StreamsChannel.broadcast_replace_to(
      "meeting_#{meeting.id}",
      target: "extracted-items-container",
      partial: "meetings/extracted_items_container",
      locals: { meeting: meeting.reload }
    )

    MeetingProcessingChannel.broadcast_to(meeting, { step: "extract", status: "completed" })
    MeetingPipeline.mark_extract!(meeting_id)
  rescue Date::Error, JSON::ParserError, HuggingFaceService::Error, GroqService::Error => e
    meeting&.update(processing_error: "Item extraction failed: #{e.message.to_s.first(220)}")
    MeetingProcessingChannel.broadcast_to(
      meeting,
      { step: "extract", status: "failed", message: e.message.to_s.first(220) }
    )
    MeetingPipeline.mark_extract!(meeting_id)
  rescue StandardError => e
    meeting&.update(processing_error: "Item extraction failed: #{e.message.to_s.first(220)}")
    MeetingProcessingChannel.broadcast_to(
      meeting,
      { step: "extract", status: "failed", message: e.message.to_s.first(220) }
    )
    MeetingPipeline.mark_extract!(meeting_id)
  end

  private
    # LLM output is not guaranteed to be ISO-8601; bad values must not fail the whole job.
    def parse_optional_due_date(value)
      return nil if value.blank?

      s = value.to_s.strip
      return nil if s.blank?

      if (m = s.match(/(\d{4}-\d{2}-\d{2})/))
        return Date.iso8601(m[1])
      end

      Date.parse(s)
    rescue ArgumentError, TypeError, Date::Error
      nil
    end
end
