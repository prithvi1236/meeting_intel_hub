# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscriptPreviewService do
  describe ".call" do
    it "returns ok with stats for a fixture transcript" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("test_transcripts/1_product_roadmap_q3.txt"),
        "text/plain",
        true
      )

      result = described_class.call(file)
      expect(result[:ok]).to eq(true)
      expect(result[:word_count]).to be_positive
      expect(result[:speaker_count]).to be_positive
    end

    it "returns error for invalid upload" do
      result = described_class.call(nil)
      expect(result[:ok]).to eq(false)
      expect(result[:error]).to be_present
    end
  end
end
