class TranscriptParserService
  # Labels before "Label: value" that are meeting metadata, not dialogue speakers.
  # (Use string literals for multi-word labels — %w splits on whitespace.)
  METADATA_SPEAKER_LABELS = [
    "meeting date",
    "date",
    "project",
    "participants",
    "attendees",
    "attendee list",
    "title",
    "agenda",
    "topic",
    "duration",
    "location",
    "recording",
    "meeting id",
    "transcript",
    "organizer",
    "notes"
  ].freeze

  # Matches a single-line colon turn: "Name: dialogue…" (same rule as parse_txt).
  TXT_COLON_SPEAKER_LINE = /\A([^:\[\]\(]{2,40}):\s*(.+)\z/

  class << self
    # Labels from lines the parser treats as meeting metadata (`Key: value`).
    def txt_metadata_field_labels(raw)
      raw.each_line.map(&:strip).reject(&:blank?).filter_map do |line|
        next unless metadata_header_line?(line)

        line.split(":", 2).first.strip
      end
    end

    # Distinct speaker names from colon-style turns only (ignores metadata lines).
    # Use for fixtures where dialogue is entirely `Name: …` lines after headers.
    def txt_colon_turn_speaker_names(raw)
      raw.split(/\r?\n/).map(&:strip).reject(&:blank?).filter_map do |line|
        next if metadata_header_line?(line)

        m = line.match(TXT_COLON_SPEAKER_LINE)
        m[1].strip if m
      end.uniq
    end

    def parse(file_content, format)
      fmt = format.to_s.downcase.delete(".")
      case fmt
      when "vtt", "webvtt"
        parse_vtt(file_content)
      when "srt"
        parse_srt(file_content)
      when "txt", "text"
        parse_txt(file_content)
      else
        parse_txt(file_content)
      end
    end

    def parse_vtt(content)
      segments = []
      body = content.sub(/\A\s*WEBVTT[^\n]*\n/i, "")
      body.scan(/(\d{2}:\d{2}:\d{2}\.\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2}\.\d{3})\s*\n([\s\S]*?)(?=\n\n|\z)/m) do |start_ts, end_ts, text_block|
        text = text_block.strip.gsub(%r{</?v[^>]*>}, " ").gsub(/\s+/, " ").strip
        speaker = text_block[%r{<v\s+([^>]+)>}i, 1]&.strip
        if speaker.blank? && text.include?(":")
          potential = text.split(":").first.strip
          next if metadata_speaker_label?(potential)

          speaker = potential
        end
        line_text = if speaker.present? && text.start_with?("#{speaker}:")
          text.sub(/\A#{Regexp.escape(speaker)}:\s*/, "")
        else
          text
        end

        segments << {
          "speaker" => speaker.presence || "Speaker",
          "text" => line_text.presence || text,
          "start_time" => timestamp_to_seconds(start_ts),
          "end_time" => timestamp_to_seconds(end_ts)
        }
      end
      segments.reject { |s| s["text"].blank? }
    end

    def parse_srt(content)
      segments = []
      content.scan(/(\d+)\s*\n(\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(\d{2}:\d{2}:\d{2},\d{3})\s*\n([\s\S]*?)(?=\n\n|\z)/m) do |_n, start_ts, end_ts, text_block|
        raw = text_block.strip.gsub(/\s+/, " ")
        speaker, line_text = split_speaker_line(raw)
        next if metadata_speaker_label?(speaker)

        segments << {
          "speaker" => speaker,
          "text" => line_text,
          "start_time" => timestamp_to_seconds(start_ts.tr(",", ".")),
          "end_time" => timestamp_to_seconds(end_ts.tr(",", "."))
        }
      end
      segments.reject { |s| s["text"].blank? }
    end

    def parse_txt(content)
      segments = []
      lines = content.split(/\r?\n/)
      current_speaker = "Speaker"
      current_start = 0
      current_end = 10
      buf = []

      flush = lambda do |end_t = nil|
        text = buf.join(" ").strip
        if text.present?
          finish = end_t.presence || current_end
          finish = current_start + 10 if finish.to_i <= current_start.to_i
          segments << {
            "speaker" => current_speaker,
            "text" => text,
            "start_time" => current_start,
            "end_time" => finish.to_i
          }
        end
        buf.clear
      end

      lines.each_with_index do |line, idx|
        line = line.strip
        next if line.blank?
        next if metadata_header_line?(line)

        if (m = line.match(/\A(\d{1,2}:\d{2}(?::\d{2})?)\s*[-=]+>\s*(\d{1,2}:\d{2}(?::\d{2})?)\z/))
          flush.call
          current_start = timestamp_to_seconds(m[1])
          current_end = timestamp_to_seconds(m[2])
          current_speaker = "Speaker"
        elsif (m = line.match(/\A\[([^\]]+)\]\s*(.*)\z/))
          flush.call(idx * 5)
          current_speaker = m[1].strip
          buf << m[2] if m[2].present?
          current_start = idx * 5
          current_end = current_start + 10
        elsif (m = line.match(/\A(.+?)\s*\((\d{1,2}:\d{2}(?::\d{2})?)\):\s*(.+)\z/))
          flush.call(timestamp_to_seconds(m[2]))
          current_speaker = m[1].strip
          buf << m[3]
          current_start = timestamp_to_seconds(m[2])
          current_end = current_start + 10
        elsif speaker_only_line?(line)
          flush.call
          current_speaker = line
          current_start = idx * 5 if current_start.to_i.zero?
          current_end = [ current_end.to_i, current_start.to_i + 10 ].max
        elsif (m = line.match(TXT_COLON_SPEAKER_LINE))
          flush.call(idx * 5)
          current_speaker = m[1].strip
          buf << m[2]
          current_start = idx * 5
          current_end = current_start + 10
        else
          buf << line
        end
      end
      flush.call
      segments.reject { |s| s["text"].blank? }
    end

    private
      def metadata_speaker_label?(name)
        name.present? && METADATA_SPEAKER_LABELS.include?(name.to_s.strip.downcase)
      end

      def metadata_header_line?(line)
        return false unless line.include?(":")

        label, rest = line.split(":", 2)
        rest.present? && metadata_speaker_label?(label)
      end

      def timestamp_to_seconds(ts)
        ts = ts.to_s.strip
        parts = ts.split(":")
        return 0 if parts.empty?

        if parts.length == 3
          h, m, sfrac = parts
          sec = sfrac.to_f
          h.to_i * 3600 + m.to_i * 60 + sec
        elsif parts.length == 2
          m, sfrac = parts
          m.to_i * 60 + sfrac.to_f
        else
          parts.first.to_f
        end.to_i
      end

      def split_speaker_line(raw)
        if (m = raw.match(/\A([^:]+):\s*(.+)\z/))
          [ m[1].strip, m[2].strip ]
        else
          [ "Speaker", raw ]
        end
      end

      def speaker_only_line?(line)
        candidate = line.to_s.strip
        return false if candidate.blank?
        return false if candidate.match?(/\A\d{1,2}:\d{2}(?::\d{2})?\z/)
        return false if candidate.match?(/\A\d{1,2}:\d{2}(?::\d{2})?\s*[-=]+>\s*\d{1,2}:\d{2}(?::\d{2})?\z/)
        return false if candidate.include?(":")
        return false if candidate.length > 40

        candidate.match?(/\A[[:alpha:]][[:alnum:] .'\-]{0,39}\z/)
      end
  end
end
