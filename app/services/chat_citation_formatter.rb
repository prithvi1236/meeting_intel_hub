# Parses and removes the model's trailing CITATIONS_JSON block from chat answers.
class ChatCitationFormatter
  class << self
    # Human-visible answer only (no machine citation line).
    def strip_machine_suffix(text)
      t = text.to_s
      i = t.index(/CITATIONS_JSON\s*:/i)
      i ? t[0, i].strip : t.strip
    end

    # Array of citation hashes from full model output, or [].
    def citations_from_text(text)
      return [] if text.blank?

      m = text.match(/CITATIONS_JSON\s*:/im)
      return [] unless m

      tail = text[m.end(0)..].to_s.lstrip
      json_slice = balanced_json_array(tail)
      return [] if json_slice.blank?

      parsed = JSON.parse(json_slice)
      parsed.is_a?(Array) ? parsed : []
    rescue JSON::ParserError
      []
    end

    private

      # First top-level JSON array in +s+ (handles "]" inside quoted strings).
      def balanced_json_array(s)
        return nil if s.blank?

        start = s.index("[")
        return nil unless start

        slice = s[start..]
        depth = 0
        in_string = false
        escape = false

        slice.each_char.with_index do |ch, i|
          if escape
            escape = false
            next
          end

          if in_string
            escape = true if ch == "\\"
            in_string = false if ch == '"'
            next
          end

          case ch
          when '"'
            in_string = true
          when "["
            depth += 1
          when "]"
            depth -= 1
            return slice[0..i] if depth.zero?
          end
        end

        nil
      end
  end
end
