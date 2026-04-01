class ChatSessionsController < ApplicationController
  include ProjectScoped

  before_action :set_project
  before_action :set_meeting, if: -> { params[:meeting_id].present? }
  before_action :set_session, only: %i[show destroy clear_messages]

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
      redirect_to project_meeting_chat_session_path(@project, @meeting, @chat_session), status: :see_other
    else
      @chat_session = @project.chat_sessions.build(chat_session_params.merge(meeting_id: nil))
      if @chat_session.save
        redirect_to project_chat_session_path(@project, @chat_session), status: :see_other
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
      redirect_to project_path(@project), status: :see_other
    else
      redirect_to project_chat_sessions_path(@project), status: :see_other
    end
  end

  def clear_messages
    @chat_session.chat_messages.destroy_all
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.update("chat-messages", "")
      end
      format.html do
        fallback =
          if params[:meeting_id].present?
            project_meeting_chat_session_path(@project, @meeting, @chat_session)
          else
            project_chat_session_path(@project, @chat_session)
          end
        redirect_back fallback_location: fallback, status: :see_other
      end
    end
  end

  private
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
