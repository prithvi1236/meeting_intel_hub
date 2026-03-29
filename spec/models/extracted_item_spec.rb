require "rails_helper"

RSpec.describe ExtractedItem, type: :model do
  describe "validations" do
    it "requires description" do
      expect(build(:extracted_item, description: "")).not_to be_valid
    end
  end

  describe "project action item counter" do
    it "updates project total_action_items_count for action_item rows only" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      create(:extracted_item, meeting: meeting, item_type: "decision")
      project.reload
      expect(project.total_action_items_count).to eq(0)

      create(:extracted_item, meeting: meeting, item_type: "action_item")
      project.reload
      expect(project.total_action_items_count).to eq(1)
    end
  end
end
