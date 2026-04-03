# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProjectAssigneeContact, type: :model do
  it "requires valid email and unique normalized name per project" do
    project = create(:project)
    create(:project_assignee_contact, project: project, assignee_name_normalized: "alice", default_email: "a@b.com")
    dup = build(:project_assignee_contact, project: project, assignee_name_normalized: "alice", default_email: "other@b.com")
    expect(dup).not_to be_valid

    invalid = build(:project_assignee_contact, project: project, assignee_name_normalized: "bob", default_email: "not-an-email")
    expect(invalid).not_to be_valid
  end

  describe "#match_keys" do
    it "includes normalized canonical name and aliases" do
      c = build(:project_assignee_contact, assignee_name_normalized: "alice", aliases: [ "A. Smith", "alice smith" ])
      expect(c.match_keys).to include("alice", "a. smith", "alice smith")
    end
  end
end
