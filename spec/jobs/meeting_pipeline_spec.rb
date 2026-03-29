require "rails_helper"

RSpec.describe MeetingPipeline do
  around do |example|
    previous = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    example.run
    Rails.cache = previous
  end

  describe ".mark_embed!, .mark_extract!, .mark_sentiment!" do
    it "sets meeting to completed only after all three stages are marked" do
      user = create(:user)
      project = create(:project, user: user)
      meeting = create(:meeting, project: project, status: "processing")

      allow(MeetingProcessingChannel).to receive(:broadcast_to)

      described_class.mark_embed!(meeting.id)
      described_class.mark_extract!(meeting.id)
      expect(meeting.reload.status).to eq("processing")

      described_class.mark_sentiment!(meeting.id)
      expect(meeting.reload.status).to eq("completed")
      expect(MeetingProcessingChannel).to have_received(:broadcast_to).with(
        meeting,
        hash_including(step: "complete", status: "completed")
      )
    end
  end
end
