# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectMeetingsGrouper do
  let(:project) { create(:project) }

  it "groups by title and sorts within group by date desc" do
    m1 = create(:meeting, project: project, title: "Standup", meeting_date: Date.new(2026, 1, 1))
    m2 = create(:meeting, project: project, title: "Standup", meeting_date: Date.new(2026, 3, 1))
    m3 = create(:meeting, project: project, title: "Other", meeting_date: Date.new(2026, 2, 1))

    grouped = described_class.call(project.meetings.includes(:transcript).to_a, group: "title", group_sort: "latest")
    standup = grouped.find { |g| g[:key] == "Standup" }
    expect(standup[:meetings].map(&:id)).to eq([ m2.id, m1.id ])
    expect(grouped.map { |g| g[:key] }).to include("Standup", "Other")
  end

  it "groups by month bucket" do
    m = create(:meeting, project: project, title: "A", meeting_date: Date.new(2026, 2, 15))
    grouped = described_class.call([ m ], group: "month", group_sort: "latest")
    expect(grouped.first[:key]).to eq("2026-02")
  end
end
