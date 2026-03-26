class ChatMessagesController < ApplicationController
  before_action :set_project
  before_action :set_chat_session

  def create
    content = params.fetch(:chat_message, {}).permit(:content)[:content].to_s.strip
    if content.blank?
      return head :unprocessable_entity
    end

    user_msg = @chat_session.chat_messages.create!(role: :user, content: content)
    assistant_msg = @chat_session.chat_messages.create!(role: :assistant, content: "")

    ChatResponseJob.perform_later(@chat_session.id, assistant_msg.id)

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("chat-messages", partial: "chat_messages/message", locals: { message: user_msg }),
          turbo_stream.append("chat-messages", partial: "chat_messages/assistant_placeholder", locals: { message: assistant_msg })
        ]
      end
      format.html { redirect_to chat_redirect_path }
    end
  end

  private
    def set_project
      @project = current_user.projects.find(params[:project_id])
    end

    def set_chat_session
      @chat_session = if params[:meeting_id]
        meeting = @project.meetings.find(params[:meeting_id])
        meeting.chat_sessions.find(params[:chat_session_id])
      else
        @project.chat_sessions.find(params[:chat_session_id])
      end
    end

    def chat_redirect_path
      if params[:meeting_id]
        project_meeting_chat_session_path(@project, @project.meetings.find(params[:meeting_id]), @chat_session)
      else
        project_chat_session_path(@project, @chat_session)
      end
    end
end
