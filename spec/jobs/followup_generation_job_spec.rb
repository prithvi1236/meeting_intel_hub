# frozen_string_literal: true

require "rails_helper"

RSpec.describe FollowupGenerationJob, type: :job do
  include ActiveJob::TestHelper

  it "calls DraftGeneratorService and broadcasts turbo for meeting scope" do
    meeting = create(:meeting)
    service = instance_double(Followup::DraftGeneratorService, call: Followup::DraftGeneratorService::Result.new(drafts_created: [], errors: []))
    allow(Followup::DraftGeneratorService).to receive(:new).with(meeting: meeting, assignee_normalized: nil).and_return(service)

    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
      "meeting_#{meeting.id}",
      hash_including(target: "followup_drafts_summary", partial: "followup_drafts/summary")
    )

    described_class.perform_now(meeting_id: meeting.id)
  end

  it "broadcasts turbo for project scope" do
    project = create(:project)
    service = instance_double(Followup::DraftGeneratorService, call: Followup::DraftGeneratorService::Result.new(drafts_created: [], errors: []))
    allow(Followup::DraftGeneratorService).to receive(:new).with(project: project, assignee_normalized: nil).and_return(service)

    expect(Turbo::StreamsChannel).to receive(:broadcast_replace_to).with(
      "project_#{project.id}",
      hash_including(target: "project_followup_drafts_summary")
    )

    described_class.perform_now(project_id: project.id)
  end

  it "skips when meeting is missing" do
    expect(Followup::DraftGeneratorService).not_to receive(:new)
    described_class.perform_now(meeting_id: SecureRandom.uuid)
  end

  it "uses the followup_generation queue" do
    expect(described_class.queue_name).to eq("followup_generation")
  end
end
