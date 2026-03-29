import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static values = { meetingId: String }

  connect() {
    const id = this.meetingIdValue
    if (!id) return

    this.subscription = consumer.subscriptions.create(
      { channel: "MeetingProcessingChannel", meeting_id: id },
      {
        received: (data) => this.applyStep(data),
      }
    )
  }

  disconnect() {
    this.subscription?.unsubscribe()
  }

  applyStep(data) {
    if (data.step === "extract" && data.status === "streaming") {
      const row = this.element.querySelector('[data-step="extract"]')
      const pre = row?.querySelector("[data-role=extract-stream]")
      if (pre && data.content != null) {
        pre.classList.remove("hidden")
        pre.textContent += data.content
      }
      return
    }

    if (data.step === "complete" && data.status === "completed") {
      const extractRow = this.element.querySelector('[data-step="extract"]')
      if (extractRow) this.resetExtractStreamPreview(extractRow)
      this.element.querySelectorAll("[data-step]").forEach((r) => {
        r.dataset.state = "done"
        const ic = r.querySelector("[data-role=icon]")
        if (ic) ic.textContent = "✓"
      })
      this.reloadFrame("extracted-items-container")
      this.reloadFrame("sentiment-dashboard")
      return
    }

    let step = data.step
    if (step === "embed_enqueued") step = "embedding"
    const row = this.element.querySelector(`[data-step="${step}"]`)
    if (!row) return
    const icon = row.querySelector("[data-role=icon]")
    if (data.status === "started") {
      row.dataset.state = "active"
      if (icon) icon.textContent = "…"
      if (step === "extract") this.resetExtractStreamPreview(row)
    }
    if (data.status === "completed") {
      row.dataset.state = "done"
      if (icon) icon.textContent = "✓"
      if (step === "extract") this.resetExtractStreamPreview(row)
      this.handleSectionRefresh(step)
    }
    if (data.status === "failed") {
      row.dataset.state = "error"
      if (icon) icon.textContent = "!"
      if (step === "extract") this.resetExtractStreamPreview(row)
      this.handleSectionRefresh(step)
    }
  }

  resetExtractStreamPreview(row) {
    const pre = row?.querySelector("[data-role=extract-stream]")
    if (!pre) return
    pre.textContent = ""
    pre.classList.add("hidden")
  }

  handleSectionRefresh(step) {
    if (step === "parsing") this.reloadFrame("transcript-summary")
    if (step === "extract") this.reloadFrame("extracted-items-container")
    if (step === "sentiment") this.reloadFrame("sentiment-dashboard")
  }

  reloadFrame(frameId) {
    const frame = document.getElementById(frameId)
    if (!frame || frame.tagName !== "TURBO-FRAME") return

    frame.setAttribute("src", window.location.href)
  }
}
