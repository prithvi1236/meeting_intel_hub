class ChatStreamingChannel < ApplicationCable::Channel
  def subscribed
    session = ChatSession.find(params[:chat_session_id])
    reject unless session.project.user_id == current_user.id

    stream_for session
  end
end
