# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Follow-up drafts", type: :request do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project, status: "completed") }

  before { sign_in_as(user) }

  describe "POST /projects/:project_id/followup_drafts/generate" do
    it "enqueues generation when the project has open action items" do
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")

      expect do
        post project_project_followup_drafts_generate_path(project)
      end.to have_enqueued_job(FollowupGenerationJob).with(project_id: project.id)

      expect(response).to redirect_to(project_path(project))
    end

    it "does not enqueue when there are no open action items" do
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "completed")

      expect do
        post project_project_followup_drafts_generate_path(project)
      end.not_to have_enqueued_job(FollowupGenerationJob)

      expect(response).to redirect_to(project_path(project))
    end

    it "passes assignee filter when provided" do
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "Pat", status: "open")

      expect do
        post project_project_followup_drafts_generate_path(project), params: { assignee_normalized: "pat" }
      end.to have_enqueued_job(FollowupGenerationJob).with(project_id: project.id, assignee_normalized: "pat")
    end
  end

  describe "POST /projects/:project_id/meetings/:meeting_id/followup_drafts/generate" do
    it "enqueues generation for the meeting scope" do
      create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")

      expect do
        post project_meeting_meeting_followup_drafts_generate_path(project, meeting)
      end.to have_enqueued_job(FollowupGenerationJob).with(meeting_id: meeting.id)

      expect(response).to redirect_to(project_meeting_path(project, meeting))
    end
  end

  describe "GET /projects/:project_id/followup_drafts" do
    it "lists project-scoped drafts" do
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")
      create(:followup_draft, meeting: meeting, extracted_item: item, assignee_name: "A", body: "Hi")

      get project_followup_drafts_path(project)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Hi")
    end
  end

  describe "PATCH .../followup_drafts/confirm_all" do
    it "confirms sendable pending drafts and enqueues send" do
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")
      draft = create(
        :followup_draft,
        meeting: meeting,
        extracted_item: item,
        assignee_name: "A",
        assignee_email: "a@example.com",
        subject: "Hello",
        body: "Body",
        status: "pending_review"
      )

      expect do
        patch confirm_all_project_meeting_followup_drafts_path(project, meeting)
      end.to have_enqueued_job(FollowupSendJob).with(draft.id)

      expect(draft.reload).to be_confirmed
      expect(draft.sender_email).to eq(user.email)
      expect(response).to redirect_to(project_meeting_followup_drafts_path(project, meeting))
    end

    it "skips drafts that are not sendable" do
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")
      create(
        :followup_draft,
        meeting: meeting,
        extracted_item: item,
        assignee_name: "A",
        assignee_email: "",
        subject: "Hi",
        body: "Body",
        status: "pending_review"
      )

      expect do
        patch confirm_all_project_meeting_followup_drafts_path(project, meeting)
      end.not_to have_enqueued_job(FollowupSendJob)

      expect(response).to redirect_to(project_meeting_followup_drafts_path(project, meeting))
      expect(flash[:alert]).to be_present
    end
  end

  describe "PATCH /followup_drafts/:id (send)" do
    it "confirms, saves fields, and enqueues send when complete" do
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")
      draft = create(
        :followup_draft,
        meeting: meeting,
        extracted_item: item,
        assignee_name: "A",
        assignee_email: "",
        subject: "Old",
        body: "Body text",
        status: "pending_review"
      )

      expect do
        patch followup_draft_path(draft), params: {
          followup_draft: {
            assignee_email: "send@example.com",
            subject: "Updated subject",
            body: "Updated body"
          }
        }
      end.to have_enqueued_job(FollowupSendJob).with(draft.id)

      draft.reload
      expect(draft).to be_confirmed
      expect(draft.sender_email).to eq(user.email)
      expect(draft.assignee_email).to eq("send@example.com")
      expect(draft.subject).to eq("Updated subject")
      expect(response).to redirect_to(project_meeting_followup_drafts_path(project, meeting))
    end

    it "rejects send when fields are incomplete" do
      item = create(:extracted_item, meeting: meeting, item_type: "action_item", owner: "A", status: "open")
      draft = create(:followup_draft, meeting: meeting, extracted_item: item, assignee_name: "A", status: "pending_review")

      expect do
        patch followup_draft_path(draft), params: {
          followup_draft: { assignee_email: "", subject: "", body: "" }
        }
      end.not_to have_enqueued_job(FollowupSendJob)

      expect(draft.reload).to be_pending_review
      expect(response).to redirect_to(project_meeting_followup_drafts_path(project, meeting))
    end
  end
end
