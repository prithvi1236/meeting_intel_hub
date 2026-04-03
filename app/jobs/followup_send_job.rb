# frozen_string_literal: true

class FollowupSendJob < ApplicationJob
  queue_as :followup_sending

  def perform(followup_draft_id)
    draft = FollowupDraft.find_by(id: followup_draft_id)
    return unless draft
    return unless draft.confirmed?

    Followup::SenderService.new(draft).call
  end
end
