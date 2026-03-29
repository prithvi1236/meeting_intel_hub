require "rails_helper"

RSpec.describe Transcript, type: :model do
  it "is valid with factory defaults" do
    expect(build(:transcript)).to be_valid
  end

  it "requires language_code" do
    expect(build(:transcript, language_code: "")).not_to be_valid
  end

  it "belongs to meeting" do
    transcript = create(:transcript)
    expect(transcript.meeting).to be_present
  end

  it "normalizes parsed_segments to string keys for downstream jobs" do
    transcript = build(
      :transcript,
      parsed_segments: [ { speaker: "Alex", text: "Hi", start_time: 0, end_time: 1 } ]
    )
    row = transcript.parsed_segments_normalized.first
    expect(row["speaker"]).to eq("Alex")
    expect(row["text"]).to eq("Hi")
  end
end
