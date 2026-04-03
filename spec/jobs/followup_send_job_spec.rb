# frozen_string_literal: true

require "rails_helper"

RSpec.describe FollowupSendJob, type: :job do
  it "skips when draft is not confirmed" do
    draft = create(:followup_draft, status: "pending_review")
    expect(Followup::SenderService).not_to receive(:new)
    described_class.perform_now(draft.id)
  end

  it "calls SenderService when confirmed" do
    meeting = create(:meeting)
    item = create(:extracted_item, meeting: meeting, item_type: "action_item")
    draft = create(:followup_draft, meeting: meeting, extracted_item: item, status: "confirmed", assignee_email: "a@b.com")
    service = instance_double(Followup::SenderService, call: Followup::SenderService::Result.new(success: true, error: nil))
    allow(Followup::SenderService).to receive(:new).with(draft).and_return(service)

    described_class.perform_now(draft.id)
    expect(service).to have_received(:call)
  end

  it "uses the followup_sending queue" do
    expect(described_class.queue_name).to eq("followup_sending")
  end
end
