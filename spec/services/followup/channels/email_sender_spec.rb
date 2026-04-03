# frozen_string_literal: true

require "rails_helper"

RSpec.describe Followup::Channels::EmailSender do
  it "enqueues FollowupMailer with draft id" do
    draft = create(:followup_draft, assignee_email: "x@y.com", subject: "Hi", status: "confirmed")

    expect do
      described_class.deliver(draft)
    end.to have_enqueued_mail(FollowupMailer, :action_item_followup).with(draft.id)
  end
end
