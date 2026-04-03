# frozen_string_literal: true

require "rails_helper"

RSpec.describe FollowupMailer, type: :mailer do
  describe "#action_item_followup" do
    it "sets to, subject, and includes action item title in body" do
      project = create(:project)
      meeting = create(:meeting, project: project, title: "Q1 Review", meeting_date: Date.new(2025, 4, 1))
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", description: "Send the report", due_date: Date.new(2025, 4, 10))
      draft = create(
        :followup_draft,
        meeting: meeting,
        extracted_item: item,
        assignee_email: "assignee@example.com",
        sender_email: "sender@example.com",
        subject: "Quick follow-up",
        body: "Thanks again."
      )

      mail = described_class.action_item_followup(draft.id)
      expect(mail.to).to eq([ "assignee@example.com" ])
      expect(mail.from).to eq([ "sender@example.com" ])
      expect(mail.subject).to eq("Quick follow-up")
      expect(mail.text_part.decoded).to include("Send the report")
      expect(mail.text_part.decoded).to include("Thanks again.")
      expect(mail.html_part.decoded).to include("Send the report")
    end

    it "falls back to FOLLOWUP_FROM when sender_email is blank" do
      stub_const("FollowupConfig::FROM_EMAIL", "fallback@example.com")
      stub_const("FollowupConfig::FROM_NAME", "App Name")

      project = create(:project)
      meeting = create(:meeting, project: project)
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", description: "Task")
      draft = create(
        :followup_draft,
        meeting: meeting,
        extracted_item: item,
        assignee_email: "to@example.com",
        sender_email: nil,
        subject: "Subj",
        body: "B"
      )

      mail = described_class.action_item_followup(draft.id)
      expect(mail.from).to eq([ "fallback@example.com" ])
    end

    it "raises when draft is missing" do
      expect do
        described_class.action_item_followup(SecureRandom.uuid).deliver_now
      end.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
