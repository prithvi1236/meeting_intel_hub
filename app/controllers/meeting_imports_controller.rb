# frozen_string_literal: true

class MeetingImportsController < ApplicationController
  before_action :set_project

  def create
    group = import_group_param
    group_sort = import_group_sort_param
    rows = normalize_import_rows
    result = Meetings::BulkCreateFromUploads.call(project: @project, rows: rows)

    if result.success
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(
              "meeting-import-errors",
              partial: "projects/meeting_import_errors",
              locals: { message: nil }
            ),
            turbo_stream.replace(
              "project-meetings-groups",
              partial: "projects/meeting_groups",
              locals: meeting_groups_locals(group, group_sort)
            )
          ]
        end
        format.html do
          redirect_to project_path(@project, group: group, group_sort: group_sort),
            notice: "Imported #{result.meetings.size} #{'meeting'.pluralize(result.meetings.size)}."
        end
      end
    else
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "meeting-import-errors",
            partial: "projects/meeting_import_errors",
            locals: { message: result.error }
          ), status: :unprocessable_entity
        end
        format.html do
          redirect_to project_path(@project), alert: result.error
        end
      end
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def import_group_param
      params[:group].presence_in(%w[title day week month]) || "title"
    end

    def import_group_sort_param
      params[:group_sort].presence_in(%w[latest name]) || "latest"
    end

    def meeting_groups_locals(group, group_sort)
      meetings = @project.meetings.includes(:transcript).to_a
      {
        project: @project,
        grouped: ProjectMeetingsGrouper.call(meetings, group: group, group_sort: group_sort),
        group: group,
        group_sort: group_sort
      }
    end

    def normalize_import_rows
      raw = params[:meeting_imports]
      return [] if raw.blank?

      list =
        if raw.is_a?(Array)
          raw
        else
          raw.to_unsafe_h.sort_by { |k, _| k.to_s.to_i }.map(&:last)
        end

      list.filter_map do |row|
        p = permit_import_row(row)
        file = p[:file]
        next if file.blank?

        {
          file: file,
          title: p[:title].to_s,
          meeting_date: p[:meeting_date].presence
        }
      end
    end

    def permit_import_row(row)
      base =
        case row
        when ActionController::Parameters
          row
        when Hash
          ActionController::Parameters.new(row)
        else
          ActionController::Parameters.new({})
        end
      base.permit(:title, :meeting_date, :file)
    end
end
