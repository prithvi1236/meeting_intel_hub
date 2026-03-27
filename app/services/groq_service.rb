class GroqService
  class Error < StandardError; end

  CHAT_MODEL = ENV.fetch("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile")
  EXTRACT_MODEL = ENV.fetch("GROQ_EXTRACT_MODEL", CHAT_MODEL)

  class << self
    def extract_items(transcript_text)
      prompt = Prompts::EXTRACT_ITEMS.sub("{{transcript}}", transcript_text.to_s.truncate(100_000))
      text = chat_completion(
        model: EXTRACT_MODEL,
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 2048,
        temperature: 0.1
      )
      normalized = HuggingFaceService.send(:normalize_extracted_items, JSON.parse(extract_json_object(text)))
      with_backfill = backfill_missing_action_items(normalized, transcript_text.to_s)
      Rails.logger.info("[GroqService] extraction decisions=#{Array(with_backfill['decisions']).size} action_items=#{Array(with_backfill['action_items']).size}")
      with_backfill
    rescue JSON::ParserError, Error
      fallback = HuggingFaceService.send(:heuristic_extract_items, transcript_text.to_s)
      Rails.logger.warn("[GroqService] fallback heuristic extraction used")
      fallback
    end

    # Yields token-sized slices for ActionCable; returns { text:, citations: }.
    def chat_with_context(user_messages:, context_chunks:)
      context = context_chunks.map { |c| "- (#{c[:meeting_title]} @ #{c[:start_time]}s): #{c[:content]}" }.join("\n")
      system = Prompts::CHAT_SYSTEM.sub("{{context}}", context.truncate(80_000))
      messages = [ { role: "system", content: system } ]
      messages.concat(user_messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } })

      full_text = chat_completion(
        model: CHAT_MODEL,
        messages: messages,
        max_tokens: 4096,
        temperature: 0.2
      )

      full_text.scan(/.{1,32}/m).each { |slice| yield slice } if block_given?
      { text: full_text, citations: parse_citations_from_text(full_text) }
    end

    private
      def chat_completion(model:, messages:, max_tokens:, temperature:)
        raise Error, "GROQ_API_KEY is missing" if groq_api_key.blank?

        response = client.post("/openai/v1/chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{groq_api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = {
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: max_tokens
          }.to_json
        end

        raise Error, "Groq HTTP #{response.status}: #{response.body}" unless response.success?

        parsed = JSON.parse(response.body)
        content = parsed.dig("choices", 0, "message", "content").to_s
        raise Error, "Groq returned empty content" if content.blank?

        content
      rescue JSON::ParserError => e
        raise Error, "Groq response parse failed: #{e.message}"
      end

      def parse_citations_from_text(text)
        if (m = text.match(/CITATIONS_JSON:\s*(\[[\s\S]*?\])/m))
          JSON.parse(m[1])
        else
          []
        end
      rescue JSON::ParserError
        []
      end

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

      def groq_api_key
        ENV["GROQ_API_KEY"].to_s
      end

      def backfill_missing_action_items(data, transcript_text)
        payload = data.is_a?(Hash) ? data.deep_dup : {}
        payload["decisions"] ||= []
        payload["action_items"] ||= []
        return payload if payload["action_items"].present?

        heuristics = HuggingFaceService.send(:heuristic_extract_items, transcript_text)
        heuristic_actions = Array(heuristics["action_items"])
        payload["action_items"] = heuristic_actions if heuristic_actions.present?
        payload
      end

      def client
        @client ||= Faraday.new(url: "https://api.groq.com") do |f|
          f.adapter Faraday.default_adapter
        end
      end
  end
end
