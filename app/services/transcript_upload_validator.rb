# frozen_string_literal: true

# Server-side checks for uploaded transcript files (extension, size, content sniff).
# Used by MeetingsController and TranscriptsController.
class TranscriptUploadValidator
  ALLOWED_EXTENSIONS = %w[txt vtt srt].freeze
  MODAL_ALLOWED_EXTENSIONS = %w[txt vtt].freeze

  MAX_FILE_BYTES = 10.megabytes

  FORMAT_HELP =
    "Allowed types: plain text (.txt), WebVTT (.vtt), SubRip (.srt).".freeze

  MODAL_FORMAT_HELP =
    "Allowed types: plain text (.txt), WebVTT (.vtt).".freeze

  UTF8_BOM = "\xEF\xBB\xBF".b.freeze

  class << self
    # @param uploaded [ActionDispatch::Http::UploadedFile, #original_filename, #open]
    # @param allowed_extensions [Array<String>] e.g. MODAL_ALLOWED_EXTENSIONS for upload modal only
    # @return [Array<String>] empty if valid, else single human-readable error string
    def validate(uploaded, allowed_extensions: ALLOWED_EXTENSIONS)
      return [ "Choose a file." ] if uploaded.blank?

      name = uploaded.original_filename.to_s
      ext = File.extname(name).delete(".").downcase
      unless allowed_extensions.include?(ext)
        help = allowed_extensions == MODAL_ALLOWED_EXTENSIONS ? MODAL_FORMAT_HELP : FORMAT_HELP
        suffix =
          if allowed_extensions == MODAL_ALLOWED_EXTENSIONS
            " The file name must end with .txt or .vtt."
          else
            " The file name must end with .txt, .vtt, or .srt."
          end
        return [ "#{help}#{suffix}" ]
      end

      size = uploaded_size(uploaded)
      help = allowed_extensions == MODAL_ALLOWED_EXTENSIONS ? MODAL_FORMAT_HELP : FORMAT_HELP
      return [ "The file is empty. #{help}" ] if size.nil? || size.zero?

      if size > MAX_FILE_BYTES
        return [ "File is too large (max #{(MAX_FILE_BYTES / 1.megabyte).to_i} MB)." ]
      end

      sample = read_sample(uploaded)
      return [ "The file could not be read. #{FORMAT_HELP}" ] if sample.nil?

      case ext
      when "vtt"
        unless looks_like_webvtt?(sample)
          return [ "This file does not look like a WebVTT transcript. #{FORMAT_HELP}" ]
        end
      when "srt"
        unless looks_like_srt?(sample)
          return [ "This file does not look like a SubRip (.srt) transcript. #{FORMAT_HELP}" ]
        end
      when "txt"
        unless valid_utf8_text?(sample)
          return [ "This file is not readable as UTF-8 text. Save as UTF-8 and try again. #{FORMAT_HELP}" ]
        end
      end

      []
    end

    private
      def uploaded_size(uploaded)
        if uploaded.respond_to?(:size) && uploaded.size
          uploaded.size.to_i
        elsif uploaded.respond_to?(:tempfile) && uploaded.tempfile
          uploaded.tempfile.size
        end
      end

      # First bytes only; always rewind so the upload can be read again for attach/save.
      def read_sample(uploaded, max = 4096)
        io = uploaded.respond_to?(:tempfile) && uploaded.tempfile ? uploaded.tempfile : uploaded
        return nil unless io.respond_to?(:read)

        io.rewind if io.respond_to?(:rewind)
        io.read(max).tap do
          io.rewind if io.respond_to?(:rewind)
        end
      rescue StandardError
        nil
      end

      def looks_like_webvtt?(sample)
        body = strip_utf8_bom_bytes(sample.to_s.b)
        first = body.each_line.map(&:strip).reject(&:blank?).first
        first&.match?(/\AWEBVTT/in)
      end

      def looks_like_srt?(sample)
        body = strip_utf8_bom_bytes(sample.to_s.b).lstrip
        return false if body.blank?

        body.match?(/\A\d+\s*\R\d{2}:\d{2}:\d{2},\d{3}\s*-->\s*\d{2}:\d{2}:\d{2},\d{3}/in)
      end

      def strip_utf8_bom_bytes(binary)
        bin = binary.b
        bom = TranscriptUploadValidator::UTF8_BOM
        bin.start_with?(bom) ? bin.byteslice(3..-1) : bin
      end

      def valid_utf8_text?(sample)
        s = sample.to_s
        s = s.dup.force_encoding(Encoding::UTF_8)
        s.valid_encoding?
      end
  end
end
