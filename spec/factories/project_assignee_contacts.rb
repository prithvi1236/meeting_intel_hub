# frozen_string_literal: true

FactoryBot.define do
  factory :project_assignee_contact do
    project
    assignee_name_normalized { "alice example" }
    default_email { "alice@example.com" }
    aliases { [] }
  end
end
