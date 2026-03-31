import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["messages", "input", "typing"]
  static values = { sessionId: String }

  connect() {
    const id = this.sessionIdValue
    if (!id) return
    this.subscription = consumer.subscriptions.create(
      { channel: "ChatStreamingChannel", chat_session_id: id },
      {
        received: (data) => this.receive(data),
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  activeBubble() {
    const nodes = this.element.querySelectorAll("[data-role=assistant-streaming]")
    return nodes[nodes.length - 1]
  }

  receive(data) {
    if (data.type === "token") {
      this.bumpTypingTimeout()
      const bubble = this.activeBubble()
      if (bubble) bubble.textContent += data.content
      this.scrollToBottom()
    }
    if (data.type === "done") {
      const bubble = this.activeBubble()
      if (bubble && data.content != null) bubble.textContent = data.content
      this.finishStream()
    }
  }

  fillSuggested(event) {
    if (!this.hasInputTarget) return
    this.inputTarget.value = event.currentTarget.textContent.trim()
    this.inputTarget.focus()
  }

  handleCitation(event) {
    const id = event.currentTarget.getAttribute("data-chunk-id")
    this.dispatch("highlight", { detail: { chunkId: id }, prefix: "citation" })
  }

  prepareSubmit() {
    this.toggleTyping(true)
    this.startTypingTimeout()
    if (this.hasInputTarget) this.inputTarget.disabled = true
  }

  turboAfterSubmit(event) {
    // If submission failed before a streaming job starts, reset UI immediately.
    if (event?.detail?.success === false) this.finishStream()
    if (this.hasInputTarget) this.inputTarget.value = ""
  }

  finishStream() {
    this.clearTypingTimeout()
    this.toggleTyping(false)
    if (this.hasInputTarget) {
      this.inputTarget.disabled = false
      this.inputTarget.focus()
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      // Submit the composer form (not the clear-chat button form).
      event.target.closest("form")?.requestSubmit()
    }
  }

  scrollToBottom() {
    if (!this.hasMessagesTarget) return
    this.messagesTarget.scrollTo({ top: this.messagesTarget.scrollHeight, behavior: "smooth" })
  }

  toggleTyping(show) {
    if (!this.hasTypingTarget) return
    this.typingTarget.classList.toggle("hidden", !show)
  }

  startTypingTimeout() {
    this.clearTypingTimeout()
    this.typingTimer = setTimeout(() => this.finishStream(), 30000)
  }

  bumpTypingTimeout() {
    if (!this.typingTimer) return
    this.startTypingTimeout()
  }

  clearTypingTimeout() {
    if (!this.typingTimer) return
    clearTimeout(this.typingTimer)
    this.typingTimer = null
  }
}
