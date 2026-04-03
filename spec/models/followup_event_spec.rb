# frozen_string_literal: true

require "rails_helper"

RSpec.describe FollowupEvent, type: :model do
  it "requires event_type and actor" do
    expect(build(:followup_event, event_type: nil)).not_to be_valid
    expect(build(:followup_event, actor: "")).not_to be_valid
  end

  it "stores enum event_type values" do
    ev = create(:followup_event, event_type: "sent")
    expect(ev.sent?).to be true
  end
end
