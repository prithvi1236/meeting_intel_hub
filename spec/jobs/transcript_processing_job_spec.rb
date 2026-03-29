require "rails_helper"

RSpec.describe TranscriptProcessingJob do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project, status: "pending") }
  let(:transcript) do
    create(:transcript, meeting: meeting, file_name: "1_product_roadmap_q3.txt", file_format: "txt")
  end

  before do
    path = Rails.root.join("test_transcripts/1_product_roadmap_q3.txt")
    transcript.file.attach(
      io: StringIO.new(File.read(path)),
      filename: "1_product_roadmap_q3.txt",
      content_type: "text/plain"
    )
    allow(EmbeddingService).to receive(:generate).and_return(Array.new(EmbeddingService::DIMENSIONS, 0.01))
    allow(ExtractItemsJob).to receive(:perform_later)
    allow(SentimentAnalysisJob).to receive(:perform_later)
    allow(MeetingProcessingChannel).to receive(:broadcast_to)
  end

  it "parses the attachment, stores segments, builds chunks, and enqueues downstream jobs" do
    described_class.perform_now(transcript.id)

    transcript.reload
    meeting.reload

    expect(transcript.parsed_segments).not_to be_empty
    expect(transcript.detected_meeting_date).to eq(Date.new(2026, 5, 12))
    expect(transcript.total_speakers).to be >= 3
    expect(meeting.speaker_count).to eq(transcript.total_speakers)
    expect(meeting.word_count).to be > 50
    expect(meeting.transcript_chunks.count).to be >= 1
    expect(ExtractItemsJob).to have_received(:perform_later).with(meeting.id)
    expect(SentimentAnalysisJob).to have_received(:perform_later).with(meeting.id)
  end

  it "marks meeting failed and re-raises when embedding raises" do
    allow(EmbeddingService).to receive(:generate).and_raise(StandardError, "embed down")

    expect do
      described_class.perform_now(transcript.id)
    end.to raise_error(StandardError, "embed down")

    expect(meeting.reload.status).to eq("failed")
    expect(meeting.processing_error).to include("embed down")
  end
end
