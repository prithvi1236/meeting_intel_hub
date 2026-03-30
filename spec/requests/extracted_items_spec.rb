# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ExtractedItems", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project) }
  let(:item) do
    create(
      :extracted_item,
      meeting: meeting,
      item_type: "action_item",
      description: "Follow up with design",
      owner: "Sam",
      due_date: Date.new(2026, 3, 15),
      status: "open"
    )
  end

  before { sign_in_as(user) }

  describe "PATCH /projects/:project_id/meetings/:meeting_id/extracted_items/:id" do
    it "updates owner and due_date and returns turbo stream" do
      patch(
        project_meeting_extracted_item_path(project, meeting, item),
        params: {
          extracted_item: {
            status: "open",
            owner: "Alex",
            due_date: "2026-04-01"
          }
        },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
      )

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq(Mime[:turbo_stream])

      item.reload
      expect(item.owner).to eq("Alex")
      expect(item.due_date).to eq(Date.new(2026, 4, 1))
    end
  end
end
