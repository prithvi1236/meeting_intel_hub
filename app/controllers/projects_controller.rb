class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = current_user.projects.includes(:meetings).ordered
  end

  def show
    @group = params[:group].presence_in(%w[title day week month]) || "title"
    @group_sort = params[:group_sort].presence_in(%w[latest name]) || "latest"
    meetings = @project.meetings.includes(:transcript).to_a
    @grouped = ProjectMeetingsGrouper.call(meetings, group: @group, group_sort: @group_sort)
    @open_upload_modal = params[:upload].present?
  end

  def new
    @project = current_user.projects.build
  end

  def edit
  end

  def create
    @project = current_user.projects.build(project_params)
    if @project.save
      redirect_to @project, notice: "Project created.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @project.destroy
      redirect_to projects_path, notice: "Project deleted.", status: :see_other
    else
      Rails.logger.error(
        "[ProjectsController#destroy] destroy returned false id=#{@project.id} errors=#{@project.errors.full_messages.inspect}"
      )
      redirect_to projects_path, alert: "Could not delete project.", status: :see_other
    end
  rescue StandardError => e
    Rails.logger.error("[ProjectsController#destroy] #{e.class}: #{e.message}\n#{e.backtrace&.first(25)&.join("\n")}")
    alert = if Rails.env.development?
      "Could not delete project: #{e.class} — see log/development.log."
    else
      "Could not delete project. If this continues, contact support."
    end
    redirect_to projects_path, alert: alert, status: :see_other
  end

  private
    def set_project
      @project = current_user.projects.find(params[:id])
    end

    def project_params
      params.expect(project: [ :name, :description, :slug ])
    end
end
