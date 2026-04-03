# frozen_string_literal: true

class FollowupGenerationJob < ApplicationJob
  queue_as :followup_generation

  retry_on GroqService::Error, wait: 30.seconds, attempts: 3
  retry_on Faraday::Error, wait: 30.seconds, attempts: 3
  retry_on Net::OpenTimeout, wait: 30.seconds, attempts: 3
  retry_on Net::ReadTimeout, wait: 30.seconds, attempts: 3

  def perform(meeting_id: nil, project_id: nil, assignee_normalized: nil)
    if meeting_id.present? == project_id.present?
      Rails.logger.warn("[FollowupGenerationJob] provide exactly one of meeting_id or project_id")
      return
    end

    if meeting_id.present?
      run_for_meeting(meeting_id, assignee_normalized: assignee_normalized)
    else
      run_for_project(project_id, assignee_normalized: assignee_normalized)
    end
  end

  private
    def run_for_meeting(meeting_id, assignee_normalized:)
      meeting = Meeting.find_by(id: meeting_id)
      unless meeting
        Rails.logger.warn("[FollowupGenerationJob] meeting not found: #{meeting_id}")
        return
      end

      result = Followup::DraftGeneratorService.new(meeting: meeting, assignee_normalized: assignee_normalized).call
      log_result(result)

      Turbo::StreamsChannel.broadcast_replace_to(
        "meeting_#{meeting.id}",
        target: "followup_drafts_summary",
        partial: "followup_drafts/summary",
        locals: { meeting: meeting.reload }
      )
    end

    def run_for_project(project_id, assignee_normalized:)
      project = Project.find_by(id: project_id)
      unless project
        Rails.logger.warn("[FollowupGenerationJob] project not found: #{project_id}")
        return
      end

      result = Followup::DraftGeneratorService.new(project: project, assignee_normalized: assignee_normalized).call
      log_result(result)

      Turbo::StreamsChannel.broadcast_replace_to(
        "project_#{project.id}",
        target: "project_followup_drafts_summary",
        partial: "followup_drafts/project_summary",
        locals: { project: project.reload }
      )
    end

    def log_result(result)
      return if result.errors.blank?

      Rails.logger.warn("[FollowupGenerationJob] generation errors: #{result.errors.join('; ')}")
    end
end
