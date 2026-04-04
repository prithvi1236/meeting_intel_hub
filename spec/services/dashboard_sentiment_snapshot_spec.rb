# frozen_string_literal: true

require "rails_helper"

RSpec.describe DashboardSentimentSnapshot do
  let(:user) { create(:user) }
  let(:project) { create(:project, user: user) }

  describe ".focus_rows" do
    it "orders projects by most negative swing when multiple scored meetings exist" do
      p_b = create(:project, user: user)
      create(:meeting, project: project, status: "completed", overall_sentiment_score: 0.8,
        meeting_date: Date.new(2026, 1, 1))
      create(:meeting, project: project, status: "completed", overall_sentiment_score: 0.2,
        meeting_date: Date.new(2026, 2, 1))

      create(:meeting, project: p_b, status: "completed", overall_sentiment_score: 0.6,
        meeting_date: Date.new(2026, 1, 5))
      create(:meeting, project: p_b, status: "completed", overall_sentiment_score: 0.55,
        meeting_date: Date.new(2026, 2, 5))

      rows = described_class.focus_rows(user, limit: 5)
      expect(rows.first.project).to eq(project)
      expect(rows.first.swing).to be_within(0.001).of(-0.6)
      expect(rows.second.swing).to be_within(0.001).of(-0.05)
    end

    it "uses last meeting score alone when only one scored meeting exists" do
      create(:meeting, project: project, status: "completed", overall_sentiment_score: -0.2,
        meeting_date: Date.new(2026, 1, 1))

      rows = described_class.focus_rows(user, limit: 5)
      expect(rows.size).to eq(1)
      expect(rows.first.swing).to be_nil
      expect(rows.first.last_score).to be_within(0.001).of(-0.2)
    end

    it "ignores pending meetings and nil scores" do
      create(:meeting, project: project, status: "pending", overall_sentiment_score: -1.0)
      create(:meeting, project: project, status: "completed", overall_sentiment_score: nil)

      expect(described_class.focus_rows(user)).to be_empty
    end
  end

  describe ".next_open_due_dates_by_project" do
    it "returns the earliest open due_date per project" do
      m1 = create(:meeting, project: project, status: "completed")
      m2 = create(:meeting, project: project, status: "completed")
      create(:extracted_item, meeting: m1, due_date: Date.new(2026, 6, 15), status: "open")
      create(:extracted_item, meeting: m2, due_date: Date.new(2026, 6, 1), status: "open")

      map = described_class.next_open_due_dates_by_project([ project.id ])
      expect(map[project.id]).to eq(Date.new(2026, 6, 1))
    end

    it "returns {} for blank ids" do
      expect(described_class.next_open_due_dates_by_project([])).to eq({})
    end
  end
end
