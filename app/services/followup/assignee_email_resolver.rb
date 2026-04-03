# frozen_string_literal: true

module Followup
  class AssigneeEmailResolver
    Result = Struct.new(:email, :status, keyword_init: true)

    def self.call(project:, assignee_display_name:)
      key = assignee_display_name.to_s.downcase.strip
      return Result.new(email: nil, status: :missing_email) if key.blank?

      contacts = project.project_assignee_contacts.to_a
      matched = contacts.select { |c| c.match_keys.include?(key) }
      emails = matched.map(&:default_email).map(&:strip).uniq

      if matched.empty?
        Result.new(email: nil, status: :missing_email)
      elsif emails.size == 1
        Result.new(email: emails.first, status: :matched)
      else
        Result.new(email: nil, status: :conflict)
      end
    end
  end
end
