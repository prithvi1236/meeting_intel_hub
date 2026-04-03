# frozen_string_literal: true

module Followup
  module Channels
    module LinearSender
      module_function

      def deliver(_draft)
        Rails.logger.warn("[Followup::LinearSender] Linear channel not yet configured")
        raise NotImplementedError, "Linear channel not yet configured. Add LINEAR_API_KEY and implement this sender."
      end
    end
  end
end
