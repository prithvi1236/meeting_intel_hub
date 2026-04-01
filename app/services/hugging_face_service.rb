class HuggingFaceService
  class Error < StandardError; end

  TEXT_MODEL = ENV.fetch("HF_TEXT_MODEL", "google/flan-t5-base")
  TEXT_MODEL_FALLBACKS = ENV.fetch("HF_TEXT_MODEL_FALLBACKS", "").split(",").map(&:strip).reject(&:blank?)
  HF_SENTIMENT_MODEL = ENV.fetch(
    "HF_SENTIMENT_MODEL",
    "cardiffnlp/twitter-roberta-base-sentiment-latest"
  )

  class << self
    def extract_items(transcript_text)
      prompt = Prompts::EXTRACT_ITEMS.sub("{{transcript}}", transcript_text.to_s.truncate(100_000))
      text = generate_text(prompt, max_tokens: 2048)
      ExtractedItems.normalize_extracted_items(JSON.parse(ExtractedItems.extract_json_object(text)))
    rescue Error, JSON::ParserError, ExtractedItems::Error
      ExtractedItems.heuristic_extract_items(transcript_text.to_s)
    end

    def analyse_sentiment_window(window_text)
      text = window_text.to_s.truncate(20_000)
      return neutral_window_response(text) if hf_api_token.blank?

      scores = hf_sentiment_scores(text)
      {
        "score" => (scores[:positive] - scores[:negative]).round(3),
        "label" => sentiment_label(scores),
        "dominant_emotion" => dominant_emotion(scores),
        "speakers" => extract_speakers_from_text(text)
      }
    end

    def analyse_speaker_sentiment(_name, lines_text)
      text = lines_text.to_s.truncate(30_000)
      return neutral_speaker_response(text) if hf_api_token.blank?

      scores = hf_sentiment_scores(text)
      {
        "average_score" => (scores[:positive] - scores[:negative]).round(3),
        "dominant_emotion" => dominant_emotion(scores),
        "segment_count" => text.lines.count
      }
    end

    private
      def generate_text(user_text, system_instruction: nil, max_tokens: 1024)
        return fallback_text(system_instruction: system_instruction) if hf_api_token.blank?

        prompt = build_prompt(user_text, system_instruction: system_instruction)
        models = [ TEXT_MODEL, *TEXT_MODEL_FALLBACKS ].uniq
        last_error = nil

        models.each do |model|
          begin
            return generate_text_with_model(prompt, model, max_tokens: max_tokens)
          rescue Error => e
            last_error = e
            next if model_not_supported_error?(e.message)

            raise
          end
        end

        raise(last_error || Error.new("No compatible Hugging Face text model available"))
      end

      def generate_text_with_model(prompt, model, max_tokens:)
        response = inference_client.post("/hf-inference/models/#{model}") do |req|
          req.headers["Authorization"] = "Bearer #{hf_api_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = {
            inputs: prompt,
            parameters: {
              max_new_tokens: [ max_tokens, 1024 ].min,
              temperature: 0.2,
              return_full_text: false
            },
            options: { wait_for_model: true }
          }.to_json
        end
        raise Error, "Hugging Face text HTTP #{response.status}: #{response.body}" unless response.success?

        data = JSON.parse(response.body)
        if data.is_a?(Hash) && data["error"].present?
          raise Error, "Hugging Face text model error (#{model}): #{data['error']}"
        end

        extract_generated_text(data)
      end

      def extract_generated_text(data)
        if data.is_a?(Array)
          first = data.first
          return first["generated_text"].to_s if first.is_a?(Hash) && first["generated_text"].present?
          return first.to_s if first.is_a?(String)
        end

        if data.is_a?(Hash)
          return data["generated_text"].to_s if data["generated_text"].present?
          return data.dig("choices", 0, "message", "content").to_s if data["choices"].is_a?(Array)
        end

        ""
      end

      def build_prompt(user_text, system_instruction: nil)
        return user_text.to_s if system_instruction.blank?

        <<~PROMPT
          System:
          #{system_instruction}

          User:
          #{user_text}
        PROMPT
      end

      def model_not_supported_error?(message)
        msg = message.to_s.downcase
        msg.include?("model_not_supported") || msg.include?("not supported")
      end

      def fallback_text(system_instruction:)
        return "No API key. CITATIONS_JSON: []" if system_instruction.present?

        '{"decisions":[],"action_items":[]}'
      end

      def hf_api_token
        ENV["HUGGINGFACE_API_TOKEN"].to_s
      end

      def hf_sentiment_scores(text)
        response = inference_client.post("/hf-inference/models/#{HF_SENTIMENT_MODEL}") do |req|
          req.headers["Authorization"] = "Bearer #{hf_api_token}"
          req.headers["Content-Type"] = "application/json"
          req.body = {
            inputs: text,
            options: { wait_for_model: true }
          }.to_json
        end
        raise Error, "Sentiment HTTP #{response.status}: #{response.body}" unless response.success?

        parsed = JSON.parse(response.body)
        if parsed.is_a?(Hash) && parsed["error"].present?
          raise Error, "Sentiment model error: #{parsed['error']}"
        end

        rows = parsed.is_a?(Array) && parsed.first.is_a?(Array) ? parsed.first : parsed
        label_scores = Array(rows).each_with_object({}) do |entry, acc|
          next unless entry.is_a?(Hash)

          label = entry["label"].to_s.upcase
          score = entry["score"].to_f
          acc[:positive] = score if label.include?("POS")
          acc[:negative] = score if label.include?("NEG")
          acc[:neutral] = score if label.include?("NEU")
        end

        {
          positive: label_scores.fetch(:positive, 0.0),
          negative: label_scores.fetch(:negative, 0.0),
          neutral: label_scores.fetch(:neutral, 0.0)
        }
      end

      def sentiment_label(scores)
        value = scores[:positive] - scores[:negative]
        return "positive" if value > 0.2
        return "negative" if value < -0.2

        "discussion"
      end

      def dominant_emotion(scores)
        {
          "positive" => scores[:positive],
          "negative" => scores[:negative],
          "neutral" => scores[:neutral]
        }.max_by { |_label, score| score }.first
      end

      def extract_speakers_from_text(text)
        text.lines.filter_map { |line| line.split(":", 2).first.to_s.strip.presence }.uniq.first(8)
      end

      def neutral_window_response(text)
        {
          "score" => 0.0,
          "label" => "discussion",
          "dominant_emotion" => "neutral",
          "speakers" => extract_speakers_from_text(text)
        }
      end

      def neutral_speaker_response(text)
        {
          "average_score" => 0.0,
          "dominant_emotion" => "neutral",
          "segment_count" => text.lines.count
        }
      end

      def inference_client
        @inference_client ||= Faraday.new(url: "https://router.huggingface.co") do |f|
          f.adapter Faraday.default_adapter
        end
      end
  end
end
