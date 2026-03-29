class ChatSessionsController < ApplicationController
  before_action :set_project
  before_action :set_meeting, if: -> { params[:meeting_id].present? }
  before_action :set_session, only: %i[show destroy]

  def index
    @sessions = @project.chat_sessions.where(meeting_id: nil).order(updated_at: :desc)
  end

  def new
    @chat_session = @project.chat_sessions.build(meeting_id: nil, title: "Project chat")
  end

  def create
    if params[:meeting_id].present?
      @meeting = @project.meetings.find(params[:meeting_id])
      @chat_session = ChatSession.create!(
        project: @project,
        meeting: @meeting,
        title: params.dig(:chat_session, :title).presence || "Chat"
      )
      redirect_to project_meeting_chat_session_path(@project, @meeting, @chat_session)
    else
      @chat_session = @project.chat_sessions.build(chat_session_params.merge(meeting_id: nil))
      if @chat_session.save
        redirect_to project_chat_session_path(@project, @chat_session)
      else
        render :new, status: :unprocessable_entity
      end
    end
  end

  def show
    @messages = @chat_session.chat_messages.order(:created_at)
    @distinct_meetings = if @chat_session.cross_meeting?
      Meeting.joins(:transcript_chunks).where(project_id: @project.id).distinct
    else
      []
    end
  end

  def destroy
    nested = params[:meeting_id].present?
    @chat_session.destroy
    if nested
      redirect_to project_path(@project)
    else
      redirect_to project_chat_sessions_path(@project)
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def set_meeting
      @meeting = @project.meetings.find(params[:meeting_id])
    end

    def set_session
      @chat_session = if params[:meeting_id]
        @meeting = @project.meetings.find(params[:meeting_id])
        @meeting.chat_sessions.find(params[:id])
      else
        @project.chat_sessions.find(params[:id])
      end
    end

    def chat_session_params
      params.expect(chat_session: [ :title ])
    end
end
