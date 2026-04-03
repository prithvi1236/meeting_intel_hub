# frozen_string_literal: true

FactoryBot.define do
  factory :followup_event do
    followup_draft
    event_type { "draft_generated" }
    actor { "system" }
    metadata { {} }
  end
end
