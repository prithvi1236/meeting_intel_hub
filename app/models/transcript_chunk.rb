class TranscriptChunk < ApplicationRecord
  belongs_to :transcript
  belongs_to :meeting
  has_many :extracted_items, dependent: :nullify

  has_neighbors :embedding

  validates :content, presence: true

  def self.search_by_embedding(embedding_vector, limit: 5, meeting_id: nil, project_id: nil)
    rel = all
    rel = rel.where(meeting_id: meeting_id) if meeting_id.present?
    if project_id.present?
      rel = rel.joins(:meeting).where(meetings: { project_id: project_id })
    end
    rel.nearest_neighbors(:embedding, embedding_vector, distance: "cosine").limit(limit)
  end
end
