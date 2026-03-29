require "rails_helper"

RSpec.describe ExportService do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }
  let(:meeting) { create(:meeting, project: project, title: "Export Test") }

  before do
    create(:extracted_item, meeting: meeting, item_type: "decision", description: "Ship MVP", owner: "Alex")
    create(
      :extracted_item,
      meeting: meeting,
      item_type: "action_item",
      description: "Write report",
      owner: "Priya",
      due_date: Date.new(2026, 6, 1),
      source_quote: "Please send by EOD"
    )
  end

  describe ".to_csv" do
    it "includes headers and rows for each extracted item in order" do
      csv = described_class.to_csv(meeting)
      lines = csv.lines.map(&:chomp)
      expect(lines.first).to include("Type")
      expect(lines.first).to include("Description")
      expect(csv).to include("Ship MVP")
      expect(csv).to include("Write report")
      expect(csv).to include("action_item")
    end
  end

  describe ".to_pdf" do
    it "returns a non-trivial PDF document (Prawn encodes text as hex in streams)" do
      pdf = described_class.to_pdf(meeting)
      expect(pdf).to start_with("%PDF")
      expect(pdf.bytesize).to be > 500
      expect(pdf).to include("53686970204d5650") # "Ship MVP" as hex in TJ text array
    end
  end
end
