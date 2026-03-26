class ProjectsController < ApplicationController
  before_action :set_project, only: %i[show edit update destroy]

  def index
    @projects = current_user.projects.includes(:meetings).ordered
  end

  def show
    @per_page = 10
    @page = params.fetch(:page, 1).to_i.clamp(1, 1_000_000)
    scope = @project.meetings.by_date
    @meeting_total = scope.count
    @meetings = scope.offset((@page - 1) * @per_page).limit(@per_page)
  end

  def new
    @project = current_user.projects.build
  end

  def edit
  end

  def create
    @project = current_user.projects.build(project_params)
    if @project.save
      redirect_to @project, notice: "Project created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @project.update(project_params)
      redirect_to @project, notice: "Project updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @project.destroy
    redirect_to projects_url, notice: "Project deleted."
  end

  private
    def set_project
      @project = current_user.projects.find(params[:id])
    end

    def project_params
      params.expect(project: [ :name, :description, :slug ])
    end
end
