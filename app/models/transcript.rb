class Transcript < ApplicationRecord
  belongs_to :meeting
  has_many :transcript_chunks, dependent: :destroy

  has_one_attached :file

  validates :language_code, presence: true
end
