# frozen_string_literal: true

class FollowupEvent < ApplicationRecord
  belongs_to :followup_draft

  enum :event_type, {
    draft_generated: "draft_generated",
    reviewed: "reviewed",
    edited: "edited",
    confirmed: "confirmed",
    dismissed: "dismissed",
    sent: "sent",
    delivery_failed: "delivery_failed",
    opened: "opened",
    replied: "replied"
  }

  validates :event_type, :actor, presence: true
end
