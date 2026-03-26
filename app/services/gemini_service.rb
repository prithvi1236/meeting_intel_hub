# Text generation via Google Gemini API (GEMINI_API_KEY).
# Replaces the previous Anthropic Claude integration with the same app-level API.
class GeminiService
  class Error < StandardError; end

  GENERATION_MODEL = ENV.fetch("GEMINI_MODEL", "gemini-2.0-flash")

  class << self
    def extract_items(transcript_text)
      prompt = Prompts::EXTRACT_ITEMS.sub("{{transcript}}", transcript_text.to_s.truncate(100_000))
      text = generate_text(prompt, max_output_tokens: 8192)
      JSON.parse(extract_json_object(text))
    end

    def analyse_sentiment_window(window_text)
      prompt = Prompts::SENTIMENT_WINDOW.sub("{{segment}}", window_text.to_s.truncate(20_000))
      text = generate_text(prompt, max_output_tokens: 1024)
      JSON.parse(extract_json_object(text))
    end

    def analyse_speaker_sentiment(name, lines_text)
      prompt = Prompts::SENTIMENT_SPEAKER
        .sub("{{name}}", name)
        .sub("{{lines}}", lines_text.to_s.truncate(30_000))
      text = generate_text(prompt, max_output_tokens: 1024)
      JSON.parse(extract_json_object(text))
    end

    # Yields token-sized slices for ActionCable; returns { text:, citations: }.
    def chat_with_context(user_messages:, context_chunks:)
      context = context_chunks.map { |c| "- (#{c[:meeting_title]} @ #{c[:start_time]}s): #{c[:content]}" }.join("\n")
      system = Prompts::CHAT_SYSTEM.sub("{{context}}", context.truncate(80_000))
      user_block = user_messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n\n")
      full_text = generate_text(user_block, system_instruction: system, max_output_tokens: 8192)

      full_text.scan(/.{1,32}/m).each { |slice| yield slice } if block_given?
      { text: full_text, citations: parse_citations_from_text(full_text) }
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

    private
      def generate_text(user_text, system_instruction: nil, max_output_tokens: 4096)
        if api_key.blank?
          return "No API key. CITATIONS_JSON: []" if system_instruction.present?
          return stub_json
        end

        path = "/v1beta/models/#{GENERATION_MODEL}:generateContent"
        body = {
          contents: [
            { role: "user", parts: [ { text: user_text } ] }
          ],
          generationConfig: {
            maxOutputTokens: max_output_tokens,
            temperature: 0.2
          }
        }
        body[:systemInstruction] = { parts: [ { text: system_instruction } ] } if system_instruction.present?

        response = client.post(path) do |req|
          req.params["key"] = api_key
          req.headers["Content-Type"] = "application/json"
          req.body = body.to_json
        end
        raise Error, "Gemini HTTP #{response.status}: #{response.body}" unless response.success?

        extract_text_from_response(response.body)
      end

      def extract_text_from_response(raw)
        data = JSON.parse(raw)
        parts = data.dig("candidates", 0, "content", "parts")
        return "" if parts.blank?

        parts.filter_map { |p| p["text"] }.join
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

      def api_key
        ENV["GEMINI_API_KEY"].to_s
      end

      def stub_json
        '{"decisions":[],"action_items":[]}'
      end

      def client
        @client ||= Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
          f.adapter Faraday.default_adapter
        end
      end
  end
end
