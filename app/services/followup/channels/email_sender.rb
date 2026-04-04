# frozen_string_literal: true

module Followup
  module Channels
    module EmailSender
      module_function

      # Always deliver_now inside FollowupSendJob so one Solid Queue worker is enough (no separate
      # ActionMailer job on the mailers queue). Errors are handled by Followup::SenderService.
      def deliver(draft)
        mail = FollowupMailer.action_item_followup(draft.id)
        MailDeliveryResendFallback.deliver_now_with_fallback(mail)
      end
    end
  end
end
