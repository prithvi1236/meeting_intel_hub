class Meeting < ApplicationRecord
  belongs_to :project, counter_cache: true
  has_one :transcript, dependent: :destroy
  has_many :transcript_chunks, dependent: :destroy
  has_many :extracted_items, dependent: :destroy
  has_many :chat_sessions, dependent: :destroy

  enum :status, { pending: "pending", processing: "processing", completed: "completed", failed: "failed" }

  validates :title, presence: true

  scope :completed, -> { where(status: :completed) }
  scope :by_date, -> { order(Arel.sql("meeting_date DESC NULLS LAST"), created_at: :desc) }

  before_save :sync_project_overall_sentiment_from_meetings

  def processing?
    status == "processing" || status == "pending"
  end

  private
    def sync_project_overall_sentiment_from_meetings
      return unless project_id

      scores = project.meetings.completed.where.not(overall_sentiment_score: nil).pluck(:overall_sentiment_score)
      avg = scores.empty? ? nil : (scores.sum.to_f / scores.size)
      project.update_column(:overall_sentiment_score, avg)
    end
end
