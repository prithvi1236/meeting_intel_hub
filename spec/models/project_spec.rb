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

  describe "#next_open_due_date" do
    let(:project) { create(:project) }

    it "returns the minimum open due_date across meetings" do
      m1 = create(:meeting, project: project, status: "completed")
      m2 = create(:meeting, project: project, status: "completed")
      create(:extracted_item, meeting: m1, due_date: Date.new(2026, 7, 20), status: "open")
      create(:extracted_item, meeting: m2, due_date: Date.new(2026, 7, 1), status: "open")

      expect(project.next_open_due_date).to eq(Date.new(2026, 7, 1))
    end

    it "reads from precomputed_lookup using UUID or string keys" do
      d = Date.new(2026, 5, 10)
      expect(project.next_open_due_date(precomputed_lookup: { project.id => d })).to eq(d)
      expect(project.next_open_due_date(precomputed_lookup: { project.id.to_s => d })).to eq(d)
    end

    it "returns nil when precomputed_lookup has no entry" do
      expect(project.next_open_due_date(precomputed_lookup: {})).to be_nil
    end
  end

  describe "destroy with transcripts" do
    it "removes project and transcript file attachments without error" do
      project = create(:project)
      meeting = create(:meeting, project: project)
      transcript = create(:transcript, meeting: meeting)
      transcript.file.attach(
        io: StringIO.new("hello"),
        filename: "notes.txt",
        content_type: "text/plain"
      )

      expect { project.destroy! }.to change(Project, :count).by(-1)
        .and change(Meeting, :count).by(-1)
        .and change(Transcript, :count).by(-1)
    end
  end
end
