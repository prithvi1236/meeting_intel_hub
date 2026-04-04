# frozen_string_literal: true

class FollowupDraft < ApplicationRecord
  belongs_to :meeting
  belongs_to :extracted_item
  has_many :followup_events, dependent: :destroy

  enum :channel, { email: "email", slack: "slack", jira: "jira", linear: "linear" }, default: :email
  enum :status, {
    pending_review: "pending_review",
    confirmed: "confirmed",
    dismissed: "dismissed",
    sent: "sent",
    failed: "failed"
  }, default: :pending_review
  enum :email_resolution_status, {
    matched: "matched",
    missing_email: "missing_email",
    conflict: "conflict"
  }, default: :missing_email

  validates :meeting, :extracted_item, :assignee_name, :body, :subject, presence: true
  validates :channel, :status, :email_resolution_status, presence: true
  validates :assignee_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :sender_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  validate :extracted_item_belongs_to_meeting

  scope :pending_review, -> { where(status: :pending_review) }
  scope :confirmed, -> { where(status: :confirmed) }
  scope :sent, -> { where(status: :sent) }
  scope :for_meeting, ->(meeting_id) { where(meeting_id: meeting_id) }
  scope :for_review_index, -> { where.not(status: %i[dismissed sent]) }

  after_create :log_draft_generated

  def ready_to_send?
    confirmed? && (scheduled_send_at.nil? || scheduled_send_at <= Time.current)
  end

  # Confirmed drafts should flip to sent/failed quickly once FollowupSendJob runs.
  def delivery_queue_stuck?(stale_after: 3.minutes)
    confirmed? && updated_at < stale_after.ago
  end

  # All fields required before the organiser can queue email delivery.
  def sendable?
    assignee_email.to_s.strip.match?(URI::MailTo::EMAIL_REGEXP) &&
      subject.to_s.strip.present? &&
      body.to_s.strip.present?
  end

  def log_event(event_type, actor: "system", metadata: {})
    followup_events.create!(event_type: event_type, actor: actor, metadata: metadata)
  end

  private
    def extracted_item_belongs_to_meeting
      return if extracted_item.blank? || meeting.blank?

      errors.add(:extracted_item, "must belong to the same meeting") if extracted_item.meeting_id != meeting_id
    end

    def log_draft_generated
      log_event(:draft_generated)
    end
end
