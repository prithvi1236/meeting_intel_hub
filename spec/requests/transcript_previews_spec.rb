# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Transcript previews", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  before { sign_in_as(user) }

  describe "POST /projects/:project_id/transcript_previews" do
    it "returns JSON stats for a valid .txt file" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test_transcripts/1_product_roadmap_q3.txt"),
        "text/plain",
        true
      )

      post project_transcript_previews_path(project),
        params: { transcript_file: file },
        headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["word_count"]).to be_positive
      expect(json["speaker_count"]).to be_positive
      expect(json).to have_key("suggested_title")
    end

    it "rejects .srt for the modal-only flow" do
      body = "1\n00:00:01,000 --> 00:00:02,000\nHello\n"
      file = Rack::Test::UploadedFile.new(
        StringIO.new(body),
        "text/plain",
        true,
        original_filename: "x.srt"
      )

      post project_transcript_previews_path(project), params: { transcript_file: file }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["error"]).to match(/\.txt or \.vtt/i)
    end
  end
end
