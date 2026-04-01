# frozen_string_literal: true

module ExtractedItems
  class Error < StandardError; end

  class << self
    def extract_json_object(text)
      t = text.to_s.strip
      if (m = t.match(/```(?:json)?\s*(\{[\s\S]*?\})\s*```/m))
        return m[1]
      end

      idx = t.index("{")
      raise Error, "No JSON in model output" unless idx

      depth = 0
      t[idx..].each_char.with_index(idx) do |ch, i|
        depth += 1 if ch == "{"
        depth -= 1 if ch == "}"
        return t[idx..i] if depth.zero?
      end
      t[idx..]
    end

    def normalize_extracted_items(data)
      payload = data.is_a?(Hash) ? data.deep_dup : {}
      payload["decisions"] = Array(payload["decisions"]).map do |decision|
        row = decision.is_a?(Hash) ? decision.deep_dup : {}
        row["description"] = concise_description(row["description"])
        row
      end
      payload["action_items"] = Array(payload["action_items"]).map do |item|
        row = item.is_a?(Hash) ? item.deep_dup : {}
        row["description"] = concise_description(row["description"])
        row
      end
      payload
    end

    def heuristic_extract_items(transcript_text)
      lines = transcript_text.to_s.lines.map(&:strip).reject(&:blank?)
      action_lines = lines.select { |line| action_line?(line) }.first(8)
      decision_lines = lines.select { |line| decision_line?(line) }.first(8)

      decisions = decision_lines.map do |line|
        {
          "description" => concise_description(line),
          "confidence" => 0.35,
          "source_quote" => line.truncate(240),
          "source_timestamp" => nil
        }
      end

      action_items = action_lines.map do |line|
        {
          "description" => concise_description(line),
          "owner" => nil,
          "due_date" => nil,
          "confidence" => 0.4,
          "source_quote" => line.truncate(240),
          "source_timestamp" => nil
        }
      end

      {
        "decisions" => decisions,
        "action_items" => action_items
      }
    end

    private

      def action_line?(line)
        down = line.downcase
        down.include?("action") ||
          down.include?("next step") ||
          down.include?("follow up") ||
          down.include?("todo") ||
          down.include?("will ") ||
          down.include?("need to")
      end

      def decision_line?(line)
        down = line.downcase
        down.include?("decided") ||
          down.include?("decision") ||
          down.include?("agreed") ||
          down.include?("we should") ||
          down.include?("we will")
      end

      def normalize_line(line)
        line.to_s.sub(/\A[^:]+:\s*/, "").strip
      end

      def concise_description(text, max_words: 20)
        normalized = normalize_line(text)
          .gsub(/\s+/, " ")
          .gsub(/^\d{1,2}:\d{2}(?::\d{2})?\s*/, "")
          .strip
        first_sentence = normalized.split(/(?<=[.!?])\s+/).first.to_s
        words = first_sentence.split
        concise = words.first(max_words).join(" ").strip
        concise = "#{concise}." if concise.present? && concise !~ /[.!?]\z/
        concise.presence || "No clear item captured."
      end
  end
end
