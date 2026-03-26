class ChatResponseJob < ApplicationJob
  queue_as :default

  def perform(chat_session_id, assistant_message_id)
    session = ChatSession.includes(:project, :meeting).find(chat_session_id)
    assistant = ChatMessage.find(assistant_message_id)

    history = session.chat_messages.where("created_at < ?", assistant.created_at).order(:created_at).map do |m|
      { role: m.role, content: m.content.to_s }
    end

    user_last = history.reverse.find { |m| m[:role] == "user" }
    chunks = VectorSearchService.search(
      user_last&.dig(:content).to_s,
      meeting_id: session.meeting_id,
      project_id: session.project_id,
      limit: 8
    )

    context = chunks.map do |c|
      {
        chunk_id: c.id,
        meeting_title: c.meeting.title,
        start_time: c.start_time,
        content: c.content
      }
    end

    result = GeminiService.chat_with_context(user_messages: history, context_chunks: context) do |token|
      ChatStreamingChannel.broadcast_to(session, { type: "token", content: token })
    end

    full_text = result[:text].to_s
    citations = result[:citations].presence
    body = full_text.gsub(/CITATIONS_JSON:\s*\[[\s\S]*?\]\s*\z/m, "").strip

    if citations.blank?
      citations = context.first(3).map do |c|
        {
          "chunk_id" => c[:chunk_id],
          "meeting_title" => c[:meeting_title],
          "timestamp" => c[:start_time],
          "quote" => c[:content].to_s.truncate(200)
        }
      end
    end

    assistant.update!(content: body, citations: citations)
    ChatStreamingChannel.broadcast_to(session, { type: "done", citations: citations })
  end
end
