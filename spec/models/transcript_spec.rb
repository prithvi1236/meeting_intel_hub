require "rails_helper"

RSpec.describe Transcript, type: :model do
  it "is valid with factory defaults" do
    expect(build(:transcript)).to be_valid
  end

  it "requires language_code" do
    expect(build(:transcript, language_code: "")).not_to be_valid
  end

  it "belongs to meeting" do
    transcript = create(:transcript)
    expect(transcript.meeting).to be_present
  end
end
