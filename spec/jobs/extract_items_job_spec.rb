# frozen_string_literal: true

require "rails_helper"

RSpec.describe ExtractItemsJob do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project, status: "processing") }

  let!(:transcript) do
    create(
      :transcript,
      meeting: meeting,
      parsed_segments: [ { "speaker" => "Alex", "text" => "Ship by Friday." } ]
    )
  end

  before do
    allow(MeetingProcessingChannel).to receive(:broadcast_to)
    allow(Turbo::StreamsChannel).to receive(:broadcast_replace_to)
    allow(MeetingPipeline).to receive(:mark_extract!)
  end

  def stub_extract!(payload)
    allow(GroqService).to receive(:extract_items) do |_text, &block|
      block&.call("")
      payload
    end
  end

  it "saves action items with nil due_date when the model returns an unparsable due_date" do
    stub_extract!(
      "decisions" => [],
      "action_items" => [
        {
          "description" => "Ship the build",
          "owner" => "Alex",
          "due_date" => "not-a-real-date",
          "confidence" => 0.9,
          "source_quote" => "Friday",
          "source_timestamp" => 0
        }
      ]
    )

    described_class.perform_now(meeting.id)

    expect(meeting.reload.processing_error).to be_blank
    item = meeting.extracted_items.sole
    expect(item.item_type).to eq("action_item")
    expect(item.due_date).to be_nil
  end

  it "parses ISO YYYY-MM-DD due dates from the model" do
    stub_extract!(
      "decisions" => [],
      "action_items" => [
        {
          "description" => "Ship",
          "owner" => "Alex",
          "due_date" => "2026-04-15",
          "confidence" => 0.9,
          "source_quote" => "x",
          "source_timestamp" => 0
        }
      ]
    )

    described_class.perform_now(meeting.id)

    expect(meeting.reload.extracted_items.sole.due_date).to eq(Date.new(2026, 4, 15))
  end
end
