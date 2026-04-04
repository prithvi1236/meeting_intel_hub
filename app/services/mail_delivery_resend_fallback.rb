# frozen_string_literal: true

# When Postmark is primary and RESEND_API_KEY is set, delivery retries via ResendApiSender
# after Postmark::Error. Envelope From uses the shared Resend address; original From becomes reply_to.
module MailDeliveryResendFallback
  class << self
    def enabled?
      ::OutboundMailConfig.postmark_configured? &&
        ::OutboundMailConfig.resend_fallback_configured? &&
        ActionMailer::Base.delivery_method == :postmark
    end

    # +message_delivery+ is an ActionMailer::MessageDelivery (e.g. FollowupMailer.action_item_followup(id)).
    def deliver_now_with_fallback(message_delivery)
      return message_delivery.deliver_now unless enabled?

      mail_message = message_delivery.message
      mail_message.raise_delivery_errors = true
      message_delivery.deliver_now
    rescue Postmark::Error => e
      deliver_via_resend!(message_delivery, e)
    end

    private

    def deliver_via_resend!(message_delivery, postmark_error)
      raise postmark_error if ::OutboundMailConfig.resend_api_key.blank?

      msg = message_delivery.message
      shared = ::OutboundMailConfig.resend_shared_from
      envelope = "#{FollowupConfig::FROM_NAME} <#{shared}>"

      params = ::ResendApiSender.build_params(msg, envelope_from: envelope)
      raise postmark_error if params.nil?

      Rails.logger.warn(
        "[MailDeliveryResendFallback] Postmark failed (#{postmark_error.class}: #{postmark_error.message}); " \
        "retrying via Resend (#{shared})"
      )

      ::ResendApiSender.deliver!(params)
    end
  end
end
