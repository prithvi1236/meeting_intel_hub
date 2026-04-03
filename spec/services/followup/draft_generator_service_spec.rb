# frozen_string_literal: true

require "rails_helper"

RSpec.describe Followup::DraftGeneratorService do
  def ai_stub_returning(json_string)
    proc do |**_kwargs|
      json_string
    end
  end

  describe "#call with meeting scope" do
    it "groups by assignee and creates one draft per open action item without existing draft" do
      project = create(:project)
      meeting = create(:meeting, project: project, title: "Sprint", meeting_date: Date.new(2025, 3, 1))
      i1 = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Alice", description: "Task A")
      i2 = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "alice", description: "Task B")
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Bob", description: "Task C")

      json = { subject: "Follow up", body: "Plain body text here." }.to_json
      service = described_class.new(
        meeting: meeting,
        ai_caller: ai_stub_returning(json)
      )

      result = service.call
      expect(result.errors).to be_empty
      expect(result.drafts_created.size).to eq(3)
      expect(FollowupDraft.where(meeting_id: meeting.id).count).to eq(3)

      alice_drafts = FollowupDraft.where(meeting_id: meeting.id).where(assignee_name: [ "Alice", "alice" ])
      expect(alice_drafts.count).to eq(2)
      expect(alice_drafts.pluck(:subject).uniq).to eq([ "Follow up" ])
    end

    it "ignores completed action items" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "completed")
      open_item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "B", status: "open")

      json = { subject: "S", body: "B" }.to_json
      result = described_class.new(meeting: meeting, ai_caller: ai_stub_returning(json)).call

      expect(result.drafts_created.size).to eq(1)
      expect(result.drafts_created.first.extracted_item_id).to eq(open_item.id)
    end

    it "retries once on JSON parse failure then succeeds" do
      meeting = create(:meeting)
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Zed", description: "One")

      calls = 0
      ai = proc do |**_kwargs|
        calls += 1
        calls == 1 ? "not json at all" : { subject: "Ok", body: "Fine" }.to_json
      end

      result = described_class.new(meeting: meeting, ai_caller: ai).call
      expect(calls).to eq(2)
      expect(result.errors).to be_empty
      expect(result.drafts_created.size).to eq(1)
    end

    it "rolls back all drafts when create fails mid-transaction" do
      meeting = create(:meeting)
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "P", description: "One")
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Q", description: "Two")

      json = { subject: "S", body: "B" }.to_json
      allow(FollowupDraft).to receive(:create!).and_call_original
      calls = 0
      allow(FollowupDraft).to receive(:create!) do |*args|
        calls += 1
        if calls >= 2
          d = FollowupDraft.new
          d.errors.add(:base, "simulated")
          raise ActiveRecord::RecordInvalid, d
        end

        FollowupDraft.create!(*args)
      end

      result = described_class.new(meeting: meeting, ai_caller: ai_stub_returning(json)).call
      expect(result.drafts_created).to eq([])
      expect(result.errors).not_to be_empty
      expect(FollowupDraft.where(meeting_id: meeting.id).count).to eq(0)
    end

    it "filters by assignee_normalized when set" do
      meeting = create(:meeting)
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Only Me", description: "A")
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Other", description: "B")

      json = { subject: "S", body: "B" }.to_json
      result = described_class.new(
        meeting: meeting,
        assignee_normalized: "only me",
        ai_caller: ai_stub_returning(json)
      ).call

      expect(result.drafts_created.size).to eq(1)
      expect(result.drafts_created.first.assignee_name).to eq("Only Me")
    end

    it "sets matched email from project assignee contact" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      create(:project_assignee_contact, project: project, assignee_name_normalized: "pat", default_email: "pat@example.com")
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Pat", description: "Do it")

      json = { subject: "S", body: "B" }.to_json
      result = described_class.new(meeting: meeting, ai_caller: ai_stub_returning(json)).call

      draft = result.drafts_created.first
      expect(draft.assignee_email).to eq("pat@example.com")
      expect(draft.matched?).to be true
    end

    it "marks conflict when two contacts match the same assignee key" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      create(:project_assignee_contact, project: project, assignee_name_normalized: "sam", default_email: "a@x.com")
      create(:project_assignee_contact, project: project, assignee_name_normalized: "samantha", default_email: "b@x.com", aliases: [ "sam" ])
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Sam", description: "Work")

      json = { subject: "S", body: "B" }.to_json
      result = described_class.new(meeting: meeting, ai_caller: ai_stub_returning(json)).call

      expect(result.drafts_created.first.conflict?).to be true
      expect(result.drafts_created.first.assignee_email).to be_blank
    end
  end

  describe "#call with project scope" do
    it "includes open items across meetings in the project" do
      project = create(:project)
      m1 = create(:meeting, project: project)
      m2 = create(:meeting, project: project)
      create(:extracted_item, meeting: m1, item_type: "action_item", owner: "Alex", description: "A1")
      create(:extracted_item, meeting: m2, item_type: "action_item", owner: "Alex", description: "A2")

      json = { subject: "S", body: "B" }.to_json
      # Two groups: (alex, m1) and (alex, m2) — two AI calls, same JSON ok
      ai = proc do |**_kwargs|
        json
      end

      result = described_class.new(project: project, ai_caller: ai).call
      expect(result.errors).to be_empty
      expect(result.drafts_created.size).to eq(2)
    end
  end

  describe "argument validation" do
    it "raises when both meeting and project are passed" do
      expect do
        described_class.new(meeting: create(:meeting), project: create(:project))
      end.to raise_error(ArgumentError)
    end
  end
end
