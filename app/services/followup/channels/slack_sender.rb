# frozen_string_literal: true

module Followup
  module Channels
    module SlackSender
      module_function

      def deliver(_draft)
        Rails.logger.warn("[Followup::SlackSender] Slack channel not yet configured")
        raise NotImplementedError, "Slack channel not yet configured. Add SLACK_BOT_TOKEN and implement this sender."
      end
    end
  end
end
