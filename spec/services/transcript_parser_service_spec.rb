require "rails_helper"

RSpec.describe TranscriptParserService do
  def fixture(name)
    Rails.root.join("spec/fixtures/files", name).read
  end

  describe ".parse" do
    it "parses TXT with bracket and colon speaker patterns" do
      raw = fixture("sample.txt")
      segs = described_class.parse(raw, "txt")
      expect(segs).not_to be_empty
      speakers = segs.map { |s| s["speaker"] }.uniq
      expect(speakers).to include("Alex", "Jordan", "Sam")
    end

    it "parses WEBVTT cues" do
      raw = fixture("sample.vtt")
      segs = described_class.parse(raw, "vtt")
      expect(segs.size).to be >= 1
      expect(segs.first).to include("speaker", "text", "start_time", "end_time")
    end

    it "parses SRT blocks" do
      raw = fixture("sample.srt")
      segs = described_class.parse(raw, "srt")
      expect(segs.size).to be >= 1
      expect(segs.first["text"]).to be_present
    end
  end
end
