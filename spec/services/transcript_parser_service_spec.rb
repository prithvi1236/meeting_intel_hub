require "rails_helper"

RSpec.describe TranscriptParserService do
  def fixture(name)
    Rails.root.join("spec/fixtures/files", name).read
  end

  def test_transcript(name)
    Rails.root.join("test_transcripts", name).read
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

    it "parses TXT meeting headers as metadata, not speakers (colon-turn fixtures)" do
      raw = test_transcript("1_product_roadmap_q3.txt")
      segs = described_class.parse(raw, "txt")
      speakers = segs.map { |s| s["speaker"] }.uniq
      metadata_labels = described_class.txt_metadata_field_labels(raw)
      expected_colon_speakers = described_class.txt_colon_turn_speaker_names(raw)

      expect(metadata_labels & speakers).to be_empty
      expect(speakers.sort).to eq(expected_colon_speakers.sort)
      expect(segs.map { |s| s["text"] }.join(" ")).to include("AI Copilot", "Mobile Dashboard")
    end

    it "parses client escalation WEBVTT with Alex, Priya, David and timestamps" do
      segs = described_class.parse(test_transcript("2_client_escalation_widgetcorp.vtt"), "vtt")
      expect(segs.size).to be >= 3
      speakers = segs.map { |s| s["speaker"] }.uniq.sort
      expect(speakers).to eq(%w[Alex David Priya].sort)
      expect(segs.first["start_time"]).to eq(0)
      expect(segs.first["text"]).to include("WidgetCorp")
    end

    it "parses engineering sync TXT without header fields as speakers" do
      raw = test_transcript("3_engineering_sync_copilot.txt")
      segs = described_class.parse(raw, "txt")
      speakers = segs.map { |s| s["speaker"] }.uniq
      metadata_labels = described_class.txt_metadata_field_labels(raw)
      expected_colon_speakers = described_class.txt_colon_turn_speaker_names(raw)

      expect(metadata_labels & speakers).to be_empty
      expect(speakers.sort).to eq(expected_colon_speakers.sort)
      expect(segs.map { |s| s["text"] }.join(" ")).to include("OpenAI")
    end

    it "defaults unknown format to TXT parsing" do
      raw = "Ann: Hello world."
      segs = described_class.parse(raw, "weird")
      expect(segs.first["speaker"]).to eq("Ann")
      expect(segs.first["text"]).to eq("Hello world.")
    end
  end
end
