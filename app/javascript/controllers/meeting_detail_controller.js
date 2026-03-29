import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "frame"]

  open(event) {
    if (event.type === "keydown") {
      if (event.key !== "Enter" && event.key !== " ") return
      event.preventDefault()
    }
    const el = event.currentTarget
    const url = el.dataset.meetingDetailPeekUrlValue
    if (!url) return
    this.frameTarget.src = url
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
    this.frameTarget.innerHTML = ""
    this.frameTarget.removeAttribute("src")
  }
}
