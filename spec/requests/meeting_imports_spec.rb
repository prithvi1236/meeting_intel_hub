# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Meeting imports", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in_as(user) }

  describe "POST /projects/:project_id/meeting_imports" do
    it "creates meetings and enqueues processing jobs" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test_transcripts/1_product_roadmap_q3.txt"),
        "text/plain",
        true
      )

      expect do
        post project_meeting_imports_path(project),
          params: {
            group: "title",
            group_sort: "latest",
            meeting_imports: {
              "0" => {
                title: "Roadmap import",
                meeting_date: Date.current.iso8601,
                file: file
              }
            }
          }
      end.to change(Meeting, :count).by(1)
        .and have_enqueued_job(TranscriptProcessingJob)

      expect(response).to have_http_status(:redirect)
    end

    it "returns unprocessable when no files are provided" do
      expect do
        post project_meeting_imports_path(project),
          params: { group: "title", group_sort: "latest", meeting_imports: {} }
      end.not_to change(Meeting, :count)

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to match(/No files/i)
    end
  end
end
