# Embeddings via Hugging Face Inference API router.
# Uses a 768-dim sentence-transformer model by default.
class EmbeddingService
  class Error < StandardError; end

  MODEL = ENV.fetch("HF_EMBEDDING_MODEL", "BAAI/bge-base-en-v1.5")
  MAX_ATTEMPTS = 3
  # Must match transcript_chunks.embedding vector dimension.
  DIMENSIONS = 768

  class << self
    # task_type/title are kept for call-site compatibility.
    def generate(text, task_type: "RETRIEVAL_DOCUMENT", title: nil)
      text = text.to_s
      return [] if text.blank?

      key = "emb:#{task_type}:#{Digest::SHA256.hexdigest(text)}"
      Rails.cache.fetch(key, expires_in: 30.days) do
        fetch_with_retry(text, task_type: task_type, title: title)
      end
    end

    private
      def fetch_with_retry(text, task_type:, title: nil)
        return Array.new(DIMENSIONS, 0.0) if api_token.blank?

        attempt = 0
        begin
          attempt += 1
          response = client.post("/hf-inference/models/#{MODEL}") do |req|
            req.headers["Authorization"] = "Bearer #{api_token}"
            req.headers["Content-Type"] = "application/json"
            req.body = {
              inputs: text,
              options: { wait_for_model: true }
            }.to_json
          end
          raise Error, "Hugging Face embed error #{response.status}: #{response.body}" unless response.success?

          data = JSON.parse(response.body)
          if data.is_a?(Hash) && data["error"].present?
            raise Error, "Hugging Face embed error: #{data['error']}"
          end

          vec = normalize_vector(data)
          raise Error, "Missing embedding values" if vec.blank?

          force_dimensions(vec)
        rescue StandardError => e
          raise e if attempt >= MAX_ATTEMPTS

          sleep(2**attempt)
          retry
        end
      end

      def client
        @client ||= Faraday.new(url: "https://router.huggingface.co") do |f|
          f.adapter Faraday.default_adapter
        end
      end

      def normalize_vector(data)
        return data.map(&:to_f) if numeric_array?(data)

        if data.is_a?(Array) && data.any? && numeric_array?(data.first)
          # Most transformer models return token embeddings (tokens x hidden_size).
          # Average pooling gives a stable fixed-size sentence embedding.
          dim = data.first.size
          sums = Array.new(dim, 0.0)
          count = 0

          data.each do |row|
            next unless numeric_array?(row)

            row.each_with_index { |val, i| sums[i] += val.to_f }
            count += 1
          end
          return [] if count.zero?

          return sums.map { |s| s / count.to_f }
        end

        []
      end

      def numeric_array?(value)
        value.is_a?(Array) && value.all? { |v| v.is_a?(Numeric) }
      end

      def force_dimensions(vec)
        arr = vec.map(&:to_f)
        if arr.size < DIMENSIONS
          arr + Array.new(DIMENSIONS - arr.size, 0.0)
        else
          arr.first(DIMENSIONS)
        end
      end

      def api_token
        ENV["HUGGINGFACE_API_TOKEN"].to_s.presence
      end
  end
end
