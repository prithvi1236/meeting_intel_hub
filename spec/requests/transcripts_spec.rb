require "rails_helper"

RSpec.describe "Transcripts", type: :request do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project) }

  before { sign_in_as(user) }

  describe "POST /projects/:project_id/meetings/:meeting_id/transcripts" do
    it "enqueues transcript processing for an allowed file from test_transcripts" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test_transcripts/3_engineering_sync_copilot.txt"),
        "text/plain",
        true
      )

      expect do
        post project_meeting_transcripts_path(project, meeting), params: { transcript_file: file }
      end.to have_enqueued_job(TranscriptProcessingJob)

      expect(response).to redirect_to(project_meeting_path(project, meeting))
      expect(meeting.reload.transcript).to be_present
      expect(meeting.transcript.file_name).to include("engineering_sync")
    end

    it "redirects with alert when no file is chosen" do
      expect do
        post project_meeting_transcripts_path(project, meeting), params: {}
      end.not_to have_enqueued_job(TranscriptProcessingJob)

      expect(response).to redirect_to(project_meeting_path(project, meeting))
      expect(flash[:alert]).to eq("Choose a file.")
    end

    it "rejects invalid extension" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("%PDF"),
        "application/pdf",
        true,
        original_filename: "x.pdf"
      )

      expect do
        post project_meeting_transcripts_path(project, meeting), params: { transcript_file: file }
      end.not_to have_enqueued_job(TranscriptProcessingJob)

      expect(response).to redirect_to(project_meeting_path(project, meeting))
      expect(flash[:alert]).to include(".txt")
    end

    it "rejects empty .txt file" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new(""),
        "text/plain",
        true,
        original_filename: "empty.txt"
      )

      expect do
        post project_meeting_transcripts_path(project, meeting), params: { transcript_file: file }
      end.not_to have_enqueued_job(TranscriptProcessingJob)

      expect(response).to redirect_to(project_meeting_path(project, meeting))
      expect(flash[:alert]).to match(/empty/i)
    end

    it "returns turbo_stream with inline error for invalid file when Accept is turbo_stream" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("nope"),
        "text/plain",
        true,
        original_filename: "bad.vtt"
      )

      post project_meeting_transcripts_path(project, meeting),
        params: { transcript_file: file },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq(Mime[:turbo_stream].to_s)
      expect(response.body).to include("transcript-upload-errors")
      expect(response.body).to match(/WebVTT|Allowed types/i)
    end
  end

  describe "DELETE /projects/:project_id/meetings/:meeting_id/transcripts/:id" do
    it "removes the transcript" do
      transcript = create(:transcript, meeting: meeting)
      delete project_meeting_transcript_path(project, meeting, transcript)
      expect(response).to redirect_to(project_meeting_path(project, meeting))
      expect(meeting.reload.transcript).to be_nil
    end
  end
end
