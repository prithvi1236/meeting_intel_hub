require "rails_helper"

RSpec.describe Meeting, type: :model do
  describe "validations" do
    it "requires title" do
      expect(build(:meeting, title: "")).not_to be_valid
    end
  end

  describe "status enum" do
    it "supports pending and completed string values" do
      m = create(:meeting, status: "pending")
      expect(m).to be_pending
      m.update!(status: "completed")
      expect(m.reload).to be_completed
    end
  end

  describe "#processing?" do
    it "is true for pending and processing statuses" do
      expect(build(:meeting, status: "pending")).to be_processing
      expect(build(:meeting, status: "processing")).to be_processing
      expect(build(:meeting, status: "completed")).not_to be_processing
    end
  end

  describe "#speaker_names_for_owner_picklist" do
    it "returns sorted unique names from parsed transcript segments and project speakers" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      create(:transcript, meeting: meeting, parsed_segments: [
        { "speaker" => "Sam", "text" => "Hi" },
        { "speaker" => "Alex", "text" => "Hey" },
        { "speaker" => "Sam", "text" => "Bye" }
      ])
      create(:speaker, project: project, name: "Jordan")

      expect(meeting.speaker_names_for_owner_picklist).to eq(%w[Alex Jordan Sam])
    end

    it "returns an empty array when there is no transcript data" do
      meeting = create(:meeting)
      expect(meeting.speaker_names_for_owner_picklist).to eq([])
    end
  end

  describe "project sentiment sync" do
    it "averages overall_sentiment_score from completed meetings when a meeting is saved" do
      project = create(:project)
      create(:meeting, project: project, title: "A", status: "completed", overall_sentiment_score: 0.2)
      second = create(:meeting, project: project, title: "B", status: "completed", overall_sentiment_score: 0.8)
      second.update!(title: "B sync")
      project.reload
      expect(project.overall_sentiment_score).to be_within(0.001).of(0.5)
    end
  end
end
