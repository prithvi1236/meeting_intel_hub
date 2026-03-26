class VectorSearchService
  class << self
    def search(query_text, meeting_id: nil, project_id: nil, limit: 5)
      embedding = EmbeddingService.generate(query_text.to_s, task_type: "RETRIEVAL_QUERY")
      return [] if embedding.blank?

      TranscriptChunk.search_by_embedding(embedding, limit: limit, meeting_id: meeting_id, project_id: project_id)
    end
  end
end
