require "rails_helper"

RSpec.describe "Api::V1::Meetings exports", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project) }

  before do
    create(:extracted_item, meeting: meeting, description: "CSV row check")
    sign_in_as(user)
  end

  describe "GET /api/v1/meetings/:id/export_items.csv" do
    it "returns CSV attachment" do
      get export_items_api_v1_meeting_path(meeting, format: :csv)
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/csv")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.body).to include("CSV row check")
    end
  end

  describe "GET /api/v1/meetings/:id/export_items.pdf" do
    it "returns PDF attachment" do
      get export_items_api_v1_meeting_path(meeting, format: :pdf)
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")
    end
  end

  it "returns not found for another user's meeting" do
    other_meeting = create(:meeting, project: create(:project, user: create(:user)))
    get export_items_api_v1_meeting_path(other_meeting, format: :csv)
    expect(response).to have_http_status(:not_found)
  end

  it "redirects to login when not authenticated" do
    delete session_path
    get export_items_api_v1_meeting_path(meeting, format: :csv)
    expect(response).to redirect_to(new_session_path)
  end
end
