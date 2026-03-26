require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "is valid with factory defaults" do
      expect(build(:user)).to be_valid
    end

    it "requires email" do
      expect(build(:user, email: "")).not_to be_valid
    end

    it "requires unique email" do
      create(:user, email: "taken@example.com")
      expect(build(:user, email: "taken@example.com")).not_to be_valid
    end
  end
end
