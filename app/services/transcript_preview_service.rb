# frozen_string_literal: true

# Synchronous parse for upload-modal preview (no embeddings / extraction jobs).
class TranscriptPreviewService
  class << self
    # @param uploaded [ActionDispatch::Http::UploadedFile]
    # @return [Hash] :ok true + stats, or :ok false + :error string
    def call(uploaded)
      errors = TranscriptUploadValidator.validate(
        uploaded,
        allowed_extensions: TranscriptUploadValidator::MODAL_ALLOWED_EXTENSIONS
      )
      return { ok: false, error: errors.first } if errors.any?

      content = read_uploaded_bytes(uploaded)
      return { ok: false, error: "The file could not be read." } if content.nil?

      fmt = File.extname(uploaded.original_filename.to_s).delete(".").downcase
      detected = TranscriptParserService.detect_meeting_date_from_raw(content)
      segments = TranscriptParserService.parse(content, fmt)
      raw = segments.map { |s| "#{s['speaker']}: #{s['text']}" }.join("\n")

      {
        ok: true,
        file_name: uploaded.original_filename.to_s,
        file_format: fmt,
        word_count: raw.split.size,
        speaker_count: segments.map { |s| s["speaker"] }.uniq.size,
        detected_meeting_date: detected&.iso8601,
        suggested_title: suggested_title_from_filename(uploaded.original_filename.to_s)
      }
    end

    private
      def read_uploaded_bytes(uploaded)
        io = uploaded.respond_to?(:tempfile) && uploaded.tempfile ? uploaded.tempfile : uploaded
        return nil unless io.respond_to?(:read)

        io.rewind if io.respond_to?(:rewind)
        io.read
      ensure
        io.rewind if io.respond_to?(:rewind)
      end

      def suggested_title_from_filename(name)
        base = File.basename(name, ".*")
        base.truncate(200, omission: "")
      end
  end
end
