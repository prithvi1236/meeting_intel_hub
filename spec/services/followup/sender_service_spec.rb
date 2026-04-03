# frozen_string_literal: true

require "rails_helper"

RSpec.describe Followup::SenderService do
  let(:meeting) { create(:meeting) }
  let(:item) { create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "X") }

  it "returns error when draft is not confirmed" do
    draft = create(:followup_draft, meeting: meeting, extracted_item: item, status: "pending_review")
    result = described_class.new(draft).call
    expect(result.success).to be false
    expect(result.error).to include("not confirmed")
  end

  it "returns error when email channel and assignee_email is blank" do
    draft = create(:followup_draft, meeting: meeting, extracted_item: item, status: "confirmed", assignee_email: "", channel: "email")
    result = described_class.new(draft).call
    expect(result.success).to be false
    expect(result.error).to include("email")
  end

  it "delegates to email sender and marks sent on success" do
    draft = create(:followup_draft, meeting: meeting, extracted_item: item, status: "confirmed", assignee_email: "a@b.com", channel: "email")
    allow(Followup::Channels::EmailSender).to receive(:deliver).with(draft)

    result = described_class.new(draft).call
    expect(result.success).to be true
    draft.reload
    expect(draft.sent?).to be true
    expect(draft.sent_at).to be_present
    expect(draft.followup_events.where(event_type: "sent").exists?).to be true
  end

  it "marks failed and logs delivery_failed when sender raises" do
    draft = create(:followup_draft, meeting: meeting, extracted_item: item, status: "confirmed", assignee_email: "a@b.com", channel: "email")
    allow(Followup::Channels::EmailSender).to receive(:deliver).and_raise(StandardError, "smtp down")

    result = described_class.new(draft).call
    expect(result.success).to be false
    draft.reload
    expect(draft.failed?).to be true
    expect(draft.delivery_error).to include("smtp down")
    ev = draft.followup_events.find_by(event_type: "delivery_failed")
    expect(ev.metadata["error"]).to include("smtp down")
  end
end
