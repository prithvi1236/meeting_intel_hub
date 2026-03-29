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

    wire = +""
    visible_sent = 0
    result = GroqService.chat_with_context(user_messages: history, context_chunks: context) do |token|
      wire << token
      cut = wire.index(/CITATIONS_JSON\s*:/i)
      visible = cut ? wire[0, cut] : wire
      next if visible.length <= visible_sent

      ChatStreamingChannel.broadcast_to(session, { type: "token", content: visible[visible_sent..] })
      visible_sent = visible.length
    end

    full_text = result[:text].to_s
    citations = result[:citations].presence
    citations = ChatCitationFormatter.citations_from_text(full_text) if citations.blank?
    body = ChatCitationFormatter.strip_machine_suffix(full_text)

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
    broadcast_final_chat_message(session, assistant)
    ChatStreamingChannel.broadcast_to(
      session,
      { type: "done", citations: citations, content: body }
    )
  rescue StandardError => e
    assistant&.update!(
      content: "Sorry, I could not generate a response right now. #{e.message.to_s.first(180)}",
      citations: []
    )
    broadcast_final_chat_message(session, assistant) if session && assistant&.persisted?
    ChatStreamingChannel.broadcast_to(
      session,
      { type: "done", citations: [], content: assistant&.content }
    ) if session
  end

  private

    def broadcast_final_chat_message(session, assistant)
      return unless assistant&.persisted?

      Turbo::StreamsChannel.broadcast_replace_to(
        "chat_session_#{session.id}",
        target: ActionView::RecordIdentifier.dom_id(assistant),
        partial: "chat_messages/message",
        locals: { message: assistant.reload }
      )
    end
end
