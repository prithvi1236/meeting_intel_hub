class TranscriptProcessingJob < ApplicationJob
  queue_as :default

  def perform(transcript_id)
    transcript = Transcript.find(transcript_id)
    meeting = transcript.meeting
    project = meeting.project

    broadcast_step(meeting, "parsing", "started")
    meeting.update!(status: :processing, processing_error: nil)

    file_content = read_attachment(transcript)
    format = transcript.file_format.presence || detect_format(transcript.file_name)

    segments = TranscriptParserService.parse(file_content, format)
    raw = segments.map { |s| "#{s['speaker']}: #{s['text']}" }.join("\n")

    transcript.update!(
      parsed_segments: segments,
      raw_content: raw,
      total_speakers: segments.map { |s| s["speaker"] }.uniq.size
    )

    meeting.update!(
      speaker_count: transcript.total_speakers,
      word_count: raw.split.size
    )

    broadcast_step(meeting, "parsing", "completed")

    broadcast_step(meeting, "embedding", "started")
    meeting.transcript_chunks.destroy_all

    chunk_attrs = TranscriptChunkerService.call(segments)
    count = 0
    chunk_attrs.each do |attrs|
      embedding = EmbeddingService.generate(attrs[:content])
      meeting.transcript_chunks.create!(
        transcript: transcript,
        content: attrs[:content],
        speaker_name: attrs[:speaker_name],
        start_time: attrs[:start_time],
        end_time: attrs[:end_time],
        chunk_index: attrs[:chunk_index],
        embedding: embedding,
        metadata: attrs[:metadata]
      )
      count += 1
    end

    broadcast_step(meeting, "embedding", "completed", count: count)

    MeetingPipeline.mark_embed!(meeting.id)

    ExtractItemsJob.perform_later(meeting.id)
    SentimentAnalysisJob.perform_later(meeting.id)

    broadcast_step(meeting, "embed_enqueued", "completed", count: count)
  rescue StandardError => e
    meeting&.update(status: :failed, processing_error: e.message)
    broadcast_step(meeting, "error", "failed", message: e.message) if meeting
    raise
  end

  private
    def read_attachment(transcript)
      return transcript.raw_content.to_s if transcript.file.blank? || !transcript.file.attached?

      transcript.file.download.force_encoding("UTF-8")
    end

    def detect_format(filename)
      File.extname(filename.to_s).delete(".").downcase
    end

    def broadcast_step(meeting, step, status, extra = {})
      MeetingProcessingChannel.broadcast_to(meeting, { step: step, status: status }.merge(extra))
    end

end
