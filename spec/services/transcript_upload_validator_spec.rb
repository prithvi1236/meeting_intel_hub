# frozen_string_literal: true

require "rails_helper"

RSpec.describe TranscriptUploadValidator do
  describe ".validate" do
    it "returns error when upload is blank" do
      expect(described_class.validate(nil)).to eq([ "Choose a file." ])
    end

    it "returns error for disallowed extension" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("hello"),
        "application/pdf",
        true,
        original_filename: "x.pdf"
      )
      expect(described_class.validate(file).first).to include(".txt")
    end

    it "returns error for empty file" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new(""),
        "text/plain",
        true,
        original_filename: "empty.txt"
      )
      expect(described_class.validate(file).first).to match(/empty/i)
    end

    it "rejects .vtt that does not start with WEBVTT" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("not webvtt"),
        "text/plain",
        true,
        original_filename: "bad.vtt"
      )
      expect(described_class.validate(file).first).to match(/WebVTT/i)
    end

    it "accepts minimal WEBVTT" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("WEBVTT\n\n"),
        "text/vtt",
        true,
        original_filename: "ok.vtt"
      )
      expect(described_class.validate(file)).to be_empty
    end

    it "accepts WEBVTT after BOM and blank lines" do
      body = "\uFEFF\n\nWEBVTT\n"
      file = Rack::Test::UploadedFile.new(
        StringIO.new(body),
        "text/vtt",
        true,
        original_filename: "ok.vtt"
      )
      expect(described_class.validate(file)).to be_empty
    end

    it "rejects .srt without cue timestamps" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("just text"),
        "text/plain",
        true,
        original_filename: "bad.srt"
      )
      expect(described_class.validate(file).first).to match(/SubRip/i)
    end

    it "accepts minimal SRT header" do
      body = "1\n00:00:01,000 --> 00:00:02,000\nHello\n"
      file = Rack::Test::UploadedFile.new(
        StringIO.new(body),
        "text/plain",
        true,
        original_filename: "ok.srt"
      )
      expect(described_class.validate(file)).to be_empty
    end

    it "accepts UTF-8 .txt" do
      file = Rack::Test::UploadedFile.new(
        StringIO.new("Speaker: hello world"),
        "text/plain",
        true,
        original_filename: "ok.txt"
      )
      expect(described_class.validate(file)).to be_empty
    end

    it "rejects .txt with invalid UTF-8" do
      bad = String.new("\xFF\xFE", encoding: Encoding::ASCII_8BIT)
      file = Rack::Test::UploadedFile.new(
        StringIO.new(bad),
        "text/plain",
        true,
        original_filename: "bad.txt"
      )
      expect(described_class.validate(file).first).to match(/UTF-8/i)
    end

    it "rejects .srt when modal extensions are used" do
      body = "1\n00:00:01,000 --> 00:00:02,000\nHello\n"
      file = Rack::Test::UploadedFile.new(
        StringIO.new(body),
        "text/plain",
        true,
        original_filename: "ok.srt"
      )
      expect(described_class.validate(file, allowed_extensions: described_class::MODAL_ALLOWED_EXTENSIONS).first).to match(/\.txt or \.vtt/i)
    end

    it "rejects files over the max size" do
      huge = "x" * (described_class::MAX_FILE_BYTES + 1)
      file = Rack::Test::UploadedFile.new(
        StringIO.new(huge),
        "text/plain",
        true,
        original_filename: "big.txt"
      )
      expect(described_class.validate(file).first).to match(/too large/i)
    end
  end
end
