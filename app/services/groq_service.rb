class GroqService
  class Error < StandardError; end

  CHAT_MODEL = ENV.fetch("GROQ_CHAT_MODEL", "llama-3.3-70b-versatile")
  EXTRACT_MODEL = ENV.fetch("GROQ_EXTRACT_MODEL", CHAT_MODEL)

  class << self
    # Uses Groq SSE streaming. Optional block receives raw completion deltas (e.g. for ActionCable).
    def extract_items(transcript_text, &block)
      prompt = Prompts::EXTRACT_ITEMS.sub("{{transcript}}", transcript_text.to_s.truncate(100_000))
      text = chat_completion_stream(
        model: EXTRACT_MODEL,
        messages: [ { role: "user", content: prompt } ],
        max_tokens: 2048,
        temperature: 0.1
      ) { |delta| block&.call(delta) }
      normalized = HuggingFaceService.send(:normalize_extracted_items, JSON.parse(extract_json_object(text)))
      with_backfill = backfill_missing_action_items(normalized, transcript_text.to_s)
      Rails.logger.info("[GroqService] extraction decisions=#{Array(with_backfill['decisions']).size} action_items=#{Array(with_backfill['action_items']).size}")
      with_backfill
    rescue JSON::ParserError, Error
      fallback = HuggingFaceService.send(:heuristic_extract_items, transcript_text.to_s)
      Rails.logger.warn("[GroqService] fallback heuristic extraction used")
      fallback
    end

    # Streams completion deltas from Groq (SSE) when a block is given — see
    # https://console.groq.com/docs/text-chat — otherwise returns the full reply.
    # Returns { text:, citations: }.
    def chat_with_context(user_messages:, context_chunks:)
      context = context_chunks.map do |c|
        "- [chunk_id=#{c[:chunk_id]}] (#{c[:meeting_title]} @ #{c[:start_time]}s): #{c[:content]}"
      end.join("\n")
      system = Prompts::CHAT_SYSTEM.sub("{{context}}", context.truncate(80_000))
      messages = [ { role: "system", content: system } ]
      messages.concat(user_messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } })

      full_text =
        if block_given?
          chat_completion_stream(
            model: CHAT_MODEL,
            messages: messages,
            max_tokens: 4096,
            temperature: 0.2
          ) { |delta| yield delta }
        else
          chat_completion(
            model: CHAT_MODEL,
            messages: messages,
            max_tokens: 4096,
            temperature: 0.2
          )
        end

      { text: full_text, citations: ChatCitationFormatter.citations_from_text(full_text) }
    end

    private
      # https://console.groq.com/docs/text-chat — stream: true yields chat.completion.chunk events.
      def chat_completion_stream(model:, messages:, max_tokens:, temperature:)
        raise Error, "GROQ_API_KEY is missing" if groq_api_key.blank?

        accumulated = +""
        sse_buffer = +""

        response = client.post("/openai/v1/chat/completions") do |req|
          req.headers["Authorization"] = "Bearer #{groq_api_key}"
          req.headers["Content-Type"] = "application/json"
          req.body = {
            model: model,
            messages: messages,
            temperature: temperature,
            max_tokens: max_tokens,
            stream: true
          }.to_json

          req.options.on_data = proc do |chunk, _size, _env|
            next if chunk.nil? || chunk.empty?

            sse_buffer << chunk.force_encoding(Encoding::UTF_8)
            drain_sse_buffer!(sse_buffer, accumulated) { |piece| yield piece if block_given? }
          end
        end

        unless response.success?
          raise Error, "Groq HTTP #{response.status}: #{response.body}"
        end

        drain_sse_buffer!(sse_buffer, accumulated, partial_line: true) { |piece| yield piece if block_given? }
        raise Error, "Groq returned empty content" if accumulated.blank?

        accumulated
      rescue JSON::ParserError => e
        raise Error, "Groq stream parse failed: #{e.message}"
      end

      def drain_sse_buffer!(buffer, accumulated, partial_line: false)
        while (idx = buffer.index("\n"))
          line = buffer.slice!(0..idx).chomp
          append_stream_delta_from_sse_line(line, accumulated) { |piece| yield piece }
        end

        return unless partial_line

        line = buffer.strip
        buffer.clear
        append_stream_delta_from_sse_line(line, accumulated) { |piece| yield piece } if line.present?
      end

      def append_stream_delta_from_sse_line(line, accumulated)
        return if line.blank? || !line.start_with?("data:")

        payload = line.sub(/\Adata:\s*/, "").strip
        return if payload == "[DONE]"

        parsed = JSON.parse(payload)
        piece = parsed.dig("choices", 0, "delta", "content")
        return if piece.blank?

        accumulated << piece
        yield piece
      end

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
