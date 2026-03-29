# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Meetings", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in_as(user) }

  describe "GET /projects/:project_id/meetings/new" do
    it "redirects to the project page to open the upload modal" do
      get new_project_meeting_path(project)
      expect(response).to redirect_to(project_path(project, upload: "1"))
    end
  end

  describe "GET /projects/:project_id/meetings/:id/peek" do
    it "returns the turbo frame partial when processing has finished" do
      meeting = create(:meeting, project: project, status: "completed")
      get peek_project_meeting_path(project, meeting)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('turbo-frame id="meeting-detail"')
    end

    it "forbids peek while the meeting is still processing" do
      meeting = create(:meeting, project: project, status: "processing")
      get peek_project_meeting_path(project, meeting)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /projects/:project_id/meetings/:id" do
    let(:meeting) { create(:meeting, project: project) }

    it "redirects to the project page" do
      get project_meeting_path(project, meeting)
      expect(response).to redirect_to(project_path(project))
    end
  end

  describe "POST /projects/:project_id/meetings" do
    it "does not create a meeting when transcript fails validation" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("not webvtt"),
        "text/plain",
        true,
        original_filename: "bad.vtt"
      )

      expect do
        post project_meetings_path(project),
          params: {
            meeting: { title: "Test", meeting_date: "" },
            transcript_file: file
          }
      end.not_to change(Meeting, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to match(/WebVTT|Allowed types/i)
    end

    it "creates meeting when transcript is valid" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test_transcripts/1_product_roadmap_q3.txt"),
        "text/plain",
        true
      )

      expect do
        post project_meetings_path(project),
          params: {
            meeting: { title: "Roadmap", meeting_date: Date.current },
            transcript_file: file
          }
      end.to change(Meeting, :count).by(1)

      expect(response).to redirect_to(project_path(project))
    end
  end
end
