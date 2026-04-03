# frozen_string_literal: true

module Followup
  module Channels
    module EmailSender
      module_function

      # In development, deliver_now runs Postmark/SMTP inside FollowupSendJob (no separate
      # MailDeliveryJob). Set FOLLOWUP_DELIVER_LATER=1 to keep deliver_later in development.
      def deliver(draft)
        mail = FollowupMailer.action_item_followup(draft.id)
        if Rails.env.development? && ENV["FOLLOWUP_DELIVER_LATER"] != "1"
          mail.deliver_now
        else
          mail.deliver_later
        end
      end
    end
  end
end
