# Embeddings via Google Gemini API (same key as GEMINI_API_KEY).
# Uses text-embedding-004 (768 dimensions). Chunk indexing vs query search use Gemini task types.
class EmbeddingService
  class Error < StandardError; end

  MODEL = ENV.fetch("GEMINI_EMBEDDING_MODEL", "text-embedding-004")
  MAX_ATTEMPTS = 3
  # Gemini text-embedding-004 outputs 768 values (must match transcript_chunks.embedding column).
  DIMENSIONS = 768

  class << self
    # task_type: "RETRIEVAL_DOCUMENT" for transcript chunks, "RETRIEVAL_QUERY" for user questions.
    def generate(text, task_type: "RETRIEVAL_DOCUMENT")
      text = text.to_s
      return [] if text.blank?

      key = "emb:#{task_type}:#{Digest::SHA256.hexdigest(text)}"
      Rails.cache.fetch(key, expires_in: 30.days) do
        fetch_with_retry(text, task_type: task_type)
      end
    end

    private
      def fetch_with_retry(text, task_type:)
        return Array.new(DIMENSIONS, 0.0) if api_key.blank?

        attempt = 0
        begin
          attempt += 1
          path = "/v1beta/models/#{MODEL}:embedContent"
          response = client.post(path) do |req|
            req.params["key"] = api_key
            req.headers["Content-Type"] = "application/json"
            req.body = {
              content: { parts: [ { text: text } ] },
              taskType: task_type
            }.to_json
          end
          raise Error, "Gemini embed error #{response.status}: #{response.body}" unless response.success?

          data = JSON.parse(response.body)
          vec = data.dig("embedding", "values")
          raise Error, "Missing embedding values" if vec.blank?

          vec.map(&:to_f)
        rescue StandardError => e
          raise e if attempt >= MAX_ATTEMPTS

          sleep(2**attempt)
          retry
        end
      end

      def client
        @client ||= Faraday.new(url: "https://generativelanguage.googleapis.com") do |f|
          f.adapter Faraday.default_adapter
        end
      end

      def api_key
        ENV["GEMINI_API_KEY"].to_s.presence
      end
  end
end
