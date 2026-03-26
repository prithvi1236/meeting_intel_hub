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
    if (data.step === "complete" && data.status === "completed") {
      this.element.querySelectorAll("[data-step]").forEach((r) => {
        r.dataset.state = "done"
        const ic = r.querySelector("[data-role=icon]")
        if (ic) ic.textContent = "✓"
      })
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
    }
    if (data.status === "completed") {
      row.dataset.state = "done"
      if (icon) icon.textContent = "✓"
    }
    if (data.status === "failed") {
      row.dataset.state = "error"
      if (icon) icon.textContent = "!"
    }
  }
}
