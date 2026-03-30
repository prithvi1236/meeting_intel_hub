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

  # Names for assigning action items: transcript turns plus any project-level Speaker rows.
  def speaker_names_for_owner_picklist
    from_segments = transcript_speaker_names_from_segments
    from_project = project.speakers.pluck(:name).map { |n| n.to_s.strip }.reject(&:blank?)
    (from_segments + from_project).uniq.sort
  end

  def broadcast_card_refresh!
    Turbo::StreamsChannel.broadcast_replace_to(
      "meeting_#{id}",
      target: ActionView::RecordIdentifier.dom_id(self, :card),
      partial: "projects/meeting_card",
      locals: { project: project, meeting: reload }
    )
  end

  private
    def transcript_speaker_names_from_segments
      segments = transcript&.parsed_segments
      return [] if segments.blank?

      Array(segments).filter_map do |seg|
        next unless seg.is_a?(Hash)

        h = seg.with_indifferent_access
        h[:speaker].to_s.strip.presence
      end.uniq
    end

    def sync_project_overall_sentiment_from_meetings
      return unless project_id

      scores = project.meetings.completed.where.not(overall_sentiment_score: nil).pluck(:overall_sentiment_score)
      avg = scores.empty? ? nil : (scores.sum.to_f / scores.size)
      project.update_column(:overall_sentiment_score, avg)
    end
end
