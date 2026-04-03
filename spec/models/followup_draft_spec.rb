# frozen_string_literal: true

require "rails_helper"

RSpec.describe FollowupDraft, type: :model do
  describe "validations" do
    it "requires core fields" do
      expect(build(:followup_draft, assignee_name: "")).not_to be_valid
      expect(build(:followup_draft, body: "")).not_to be_valid
      expect(build(:followup_draft, subject: "")).not_to be_valid
    end

    it "validates assignee_email format when present" do
      expect(build(:followup_draft, assignee_email: "bad")).not_to be_valid
      expect(build(:followup_draft, assignee_email: "ok@example.com")).to be_valid
    end

    it "requires extracted_item to belong to the same meeting" do
      other_meeting = create(:meeting)
      draft = build(:followup_draft, meeting: create(:meeting), extracted_item: create(:extracted_item, meeting: other_meeting))
      expect(draft).not_to be_valid
    end
  end

  describe "scopes" do
    it "filters by pending_review, confirmed, sent, for_meeting" do
      m1 = create(:meeting)
      m2 = create(:meeting)
      d1 = create(:followup_draft, meeting: m1, status: "pending_review")
      d2 = create(:followup_draft, meeting: m1, status: "confirmed")
      d3 = create(:followup_draft, meeting: m2, status: "sent")
      d4 = create(:followup_draft, meeting: m1, status: "dismissed")

      ids = [ d1.id, d2.id, d3.id, d4.id ]
      expect(described_class.pending_review.where(id: ids)).to contain_exactly(d1)
      expect(described_class.confirmed.where(id: ids)).to contain_exactly(d2)
      expect(described_class.sent.where(id: ids)).to contain_exactly(d3)
      expect(described_class.for_meeting(m1.id).where(id: ids).count).to eq(3)
      expect(described_class.for_review_index.where(id: ids)).to contain_exactly(d1, d2)
    end
  end

  describe "#sendable?" do
    it "is true when to, subject, and body are present and email is valid" do
      draft = build(:followup_draft, assignee_email: "a@b.com", subject: "Hi", body: "Text")
      expect(draft).to be_sendable
    end

    it "is false when any field is blank or email is invalid" do
      expect(build(:followup_draft, assignee_email: "", subject: "Hi", body: "Text")).not_to be_sendable
      expect(build(:followup_draft, assignee_email: "a@b.com", subject: "", body: "Text")).not_to be_sendable
      expect(build(:followup_draft, assignee_email: "a@b.com", subject: "Hi", body: "")).not_to be_sendable
      expect(build(:followup_draft, assignee_email: "nope", subject: "Hi", body: "Text")).not_to be_sendable
    end
  end

  describe "#ready_to_send?" do
    it "is true when confirmed and send time is nil or past" do
      draft = create(:followup_draft, status: "confirmed", scheduled_send_at: nil)
      expect(draft.ready_to_send?).to be true

      travel_to Time.zone.parse("2025-06-01 12:00:00") do
        d2 = create(:followup_draft, status: "confirmed", scheduled_send_at: 1.hour.ago)
        expect(d2.ready_to_send?).to be true
        d3 = create(:followup_draft, status: "confirmed", scheduled_send_at: 1.hour.from_now)
        expect(d3.ready_to_send?).to be false
      end
    end

    it "is false when not confirmed" do
      draft = create(:followup_draft, status: "pending_review")
      expect(draft.ready_to_send?).to be false
    end
  end

  describe "#log_event and after_create" do
    it "creates draft_generated on create" do
      draft = create(:followup_draft)
      expect(draft.followup_events.where(event_type: "draft_generated").count).to eq(1)
    end

    it "appends events via log_event" do
      draft = create(:followup_draft)
      draft.followup_events.where.not(event_type: "draft_generated").delete_all
      draft.log_event(:reviewed, actor: "user-1", metadata: { foo: "bar" })
      ev = draft.followup_events.find_by(event_type: "reviewed")
      expect(ev.actor).to eq("user-1")
      expect(ev.metadata["foo"]).to eq("bar")
    end
  end
end
