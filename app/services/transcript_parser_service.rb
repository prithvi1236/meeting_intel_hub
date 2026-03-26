class TranscriptParserService
  class << self
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
        speaker ||= text.split(":").first.strip if text.include?(":")
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
      buf = []

      flush = lambda do |end_t|
        text = buf.join(" ").strip
        if text.present?
          segments << {
            "speaker" => current_speaker,
            "text" => text,
            "start_time" => current_start,
            "end_time" => end_t
          }
        end
        buf.clear
      end

      lines.each_with_index do |line, idx|
        line = line.strip
        next if line.blank?

        if (m = line.match(/\A\[([^\]]+)\]\s*(.*)\z/))
          flush.call(idx * 5)
          current_speaker = m[1].strip
          buf << m[2] if m[2].present?
          current_start = idx * 5
        elsif (m = line.match(/\A(.+?)\s*\((\d{1,2}:\d{2}(?::\d{2})?)\):\s*(.+)\z/))
          flush.call(timestamp_to_seconds(m[2]))
          current_speaker = m[1].strip
          buf << m[3]
          current_start = timestamp_to_seconds(m[2])
        elsif (m = line.match(/\A([^:\[\]\(]{2,40}):\s*(.+)\z/))
          flush.call(idx * 5)
          current_speaker = m[1].strip
          buf << m[2]
          current_start = idx * 5
        else
          buf << line
        end
      end
      flush.call(segments.last&.fetch("end_time", 0).to_i + 10)
      segments.reject { |s| s["text"].blank? }
    end

    private
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
  end
end
