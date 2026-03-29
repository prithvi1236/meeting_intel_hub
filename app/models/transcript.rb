class Transcript < ApplicationRecord
  belongs_to :meeting
  has_many :transcript_chunks, dependent: :destroy

  has_one_attached :file

  validates :language_code, presence: true

  # JSONB may deserialize with string keys; some paths may use symbols. Normalize so
  # jobs and views always read "speaker", "text", etc. consistently.
  def parsed_segments_normalized
    Array(parsed_segments).filter_map do |raw|
      next unless raw.is_a?(Hash)

      raw.stringify_keys
    end
  end
end
