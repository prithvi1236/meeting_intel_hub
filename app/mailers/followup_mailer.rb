# frozen_string_literal: true

class FollowupMailer < ApplicationMailer
  after_action :log_followup_mail

  def action_item_followup(followup_draft_id)
    @draft = FollowupDraft.includes(extracted_item: { meeting: { project: :user } }).find(followup_draft_id)
    @meeting = @draft.meeting
    @action_item = @draft.extracted_item
    @organiser_name = @meeting.project.user.email
    mail(
      from: followup_from_header,
      to: @draft.assignee_email,
      subject: @draft.subject
    )
  end

  private
    def followup_from_header
      if @draft.sender_email.present?
        @draft.sender_email
      else
        "#{FollowupConfig::FROM_NAME} <#{FollowupConfig::FROM_EMAIL}>"
      end
    end

    def log_followup_mail
      return unless @draft

      Rails.logger.info(
        "[FollowupMailer] message for draft #{@draft.id} to=#{@draft.assignee_email.inspect} " \
        "subject=#{@draft.subject.inspect} delivery_method=#{ActionMailer::Base.delivery_method}"
      )
    end
end
