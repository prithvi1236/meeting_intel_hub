# frozen_string_literal: true

require "rails_helper"

RSpec.describe Followup::Channels::EmailSender do
  it "delivers FollowupMailer immediately (no separate ActionMailer job)" do
    draft = create(:followup_draft, assignee_email: "x@y.com", subject: "Hi", status: "confirmed")

    expect do
      described_class.deliver(draft)
    end.to change { ActionMailer::Base.deliveries.size }.by(1)

    mail = ActionMailer::Base.deliveries.last
    expect(mail.to).to eq([ "x@y.com" ])
    expect(mail.subject).to eq("Hi")
  end
end
