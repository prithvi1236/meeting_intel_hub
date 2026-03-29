require "rails_helper"

RSpec.describe TranscriptChunkerService do
  let(:segments) do
    raw = Rails.root.join("test_transcripts/1_product_roadmap_q3.txt").read
    TranscriptParserService.parse(raw, "txt")
  end

  describe ".call" do
    it "returns empty array for empty segments" do
      expect(described_class.call([])).to eq([])
    end

    it "chunks parsed test_transcript segments with indices and speaker metadata" do
      chunks = described_class.call(segments, words_per_chunk: 50, overlap: 5)
      expect(chunks).not_to be_empty
      expect(chunks.first).to include(:content, :speaker_name, :start_time, :end_time, :chunk_index, :metadata)
      expect(chunks.map { |c| c[:chunk_index] }).to eq((0...chunks.size).to_a)
      expect(chunks.first[:metadata]["speakers_in_chunk"]).to be_an(Array)
    end

    it "honors small word limits for deterministic splitting" do
      tiny = [
        { "speaker" => "A", "text" => "one two three four", "start_time" => 0, "end_time" => 10 },
        { "speaker" => "B", "text" => "five six", "start_time" => 10, "end_time" => 20 }
      ]
      chunks = described_class.call(tiny, words_per_chunk: 3, overlap: 1)
      expect(chunks.size).to be >= 2
    end
  end
end
