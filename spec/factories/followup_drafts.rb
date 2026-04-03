# frozen_string_literal: true

FactoryBot.define do
  factory :followup_draft do
    meeting
    extracted_item do
      association :extracted_item,
                    meeting: meeting,
                    item_type: "action_item",
                    owner: "Alice Example",
                    description: "Follow up on the proposal"
    end
    assignee_name { "Alice Example" }
    subject { "Quick follow-up" }
    body { "Here is a concise follow-up from our meeting." }
    email_resolution_status { "missing_email" }
  end
end
