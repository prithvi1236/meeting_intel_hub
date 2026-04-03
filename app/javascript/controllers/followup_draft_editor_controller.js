import { Controller } from "@hotwired/stimulus"

// Hides the missing-email badge once the user starts editing.
export default class extends Controller {
  static targets = ["missingEmailBadge"]

  handleInput(event) {
    if (!this.hasMissingEmailBadgeTarget) return
    if (event.target.value.trim().length === 0) return

    this.missingEmailBadgeTarget.classList.add("hidden")
  }
}
