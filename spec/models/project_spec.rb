require "rails_helper"

RSpec.describe Project, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:project)).to be_valid
    end

    it "requires name" do
      expect(build(:project, name: "")).not_to be_valid
    end

    it "auto-assigns a unique slug from name" do
      create(:project, name: "Acme Corp")
      second = create(:project, name: "Acme Corp")
      expect(second.slug).to eq("acme-corp-2")
    end
  end

  describe "#last_meeting_date" do
    it "returns the latest meeting_date among meetings" do
      project = create(:project)
      create(:meeting, project: project, meeting_date: Date.new(2026, 1, 1))
      create(:meeting, project: project, meeting_date: Date.new(2026, 3, 15))
      expect(project.last_meeting_date).to eq(Date.new(2026, 3, 15))
    end
  end
end
