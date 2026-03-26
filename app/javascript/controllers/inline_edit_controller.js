import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form"]

  showForm() {
    if (this.hasDisplayTarget) this.displayTarget.classList.add("hidden")
    if (this.hasFormTarget) this.formTarget.classList.remove("hidden")
    this.formTarget?.querySelector("input, select, textarea")?.focus()
  }

  cancel() {
    if (this.hasDisplayTarget) this.displayTarget.classList.remove("hidden")
    if (this.hasFormTarget) this.formTarget.classList.add("hidden")
  }
}
