# frozen_string_literal: true

module Followup
  module PromptBuilder
    module_function

    def followup_user_message(meeting:, assignee_display_name:, items:)
      lines = []
      lines << "Meeting title: #{meeting.title}"
      lines << "Meeting date: #{format_date(meeting.meeting_date)}"
      lines << "Assignee: #{assignee_display_name}"
      lines << ""
      lines << "Action items for this person:"
      items.each_with_index do |item, idx|
        lines << "#{idx + 1}. #{item.description.to_s.strip}"
        lines << "   Due: #{format_date(item.due_date)}" if item.due_date.present?
        excerpt = item.source_quote.presence || item.description.to_s.truncate(400)
        lines << "   Context: #{excerpt}" if excerpt.present?
      end
      lines << ""
      lines << instructions
      lines.join("\n")
    end

    def json_retry_addendum
      "Respond only with a single valid JSON object and nothing else. No markdown fences."
    end

    def instructions
      <<~TXT.squish
        Write a professional but warm follow-up email as if you are the meeting organiser,
        addressing the assignee by name where natural. Summarise their action items clearly.
        Output a single JSON object with exactly two keys: "subject" (string, concise email subject line)
        and "body" (string, plain text only, no markdown, suitable for the email body).
      TXT
    end

    def format_date(value)
      return "not specified" if value.blank?

      value.is_a?(Date) ? I18n.l(value, format: :long) : value.to_s
    end
  end
end
