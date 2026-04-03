# frozen_string_literal: true

module Followup
  module Channels
    module JiraSender
      module_function

      def deliver(_draft)
        Rails.logger.warn("[Followup::JiraSender] Jira channel not yet configured")
        raise NotImplementedError, "Jira channel not yet configured. Add JIRA credentials and implement this sender."
      end
    end
  end
end
