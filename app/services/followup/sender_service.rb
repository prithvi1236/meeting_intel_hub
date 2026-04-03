# frozen_string_literal: true

module Followup
  class SenderService
    Result = Struct.new(:success, :error, keyword_init: true)

    def initialize(followup_draft)
      @draft = followup_draft
    end

    def call
      unless @draft.confirmed?
        return Result.new(success: false, error: "Draft is not confirmed")
      end

      if @draft.email? && @draft.assignee_email.blank?
        return Result.new(success: false, error: "Assignee email is required for email channel")
      end

      channel_sender.deliver(@draft)
      @draft.update!(status: :sent, sent_at: Time.current, delivery_error: nil)
      @draft.log_event(:sent)
      Result.new(success: true, error: nil)
    rescue NotImplementedError => e
      fail_delivery!(e.message)
      Result.new(success: false, error: e.message)
    rescue StandardError => e
      fail_delivery!(e.message)
      Result.new(success: false, error: e.message)
    end

    private
      def channel_sender
        case @draft.channel
        when "email"
          Followup::Channels::EmailSender
        when "slack"
          Followup::Channels::SlackSender
        when "jira"
          Followup::Channels::JiraSender
        when "linear"
          Followup::Channels::LinearSender
        else
          Followup::Channels::EmailSender
        end
      end

      def fail_delivery!(message)
        @draft.update!(status: :failed, delivery_error: message)
        @draft.log_event(:delivery_failed, metadata: { error: message })
      end
  end
end
