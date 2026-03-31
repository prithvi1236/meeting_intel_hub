import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["view", "edit", "toggleButton"]

  connect() {
    this.editingValue = false
    this.sync()
  }

  async toggle() {
    if (this.editingValue) {
      try {
        if (this.hasToggleButtonTarget) this.toggleButtonTarget.disabled = true
        await this.saveAllForms()
        this.editingValue = false
        this.sync()
      } catch (e) {
        console.error(e)
      } finally {
        if (this.hasToggleButtonTarget) this.toggleButtonTarget.disabled = false
      }
    } else {
      this.editingValue = true
      this.sync()
    }
  }

  saveAllForms() {
    if (!this.hasEditTarget) return Promise.resolve()

    const forms = Array.from(this.editTarget.querySelectorAll("form"))
    if (forms.length === 0) return Promise.resolve()

    return forms.reduce(
      (chain, form) =>
        chain.then(
          () =>
            new Promise((resolve, reject) => {
              const onEnd = (event) => {
                form.removeEventListener("turbo:submit-end", onEnd)
                if (event.detail.success) resolve()
                else reject(new Error("Save failed"))
              }
              form.addEventListener("turbo:submit-end", onEnd)
              form.requestSubmit()
            })
        ),
      Promise.resolve()
    )
  }

  sync() {
    if (this.hasViewTarget) this.viewTarget.classList.toggle("hidden", this.editingValue)
    if (this.hasEditTarget) this.editTarget.classList.toggle("hidden", !this.editingValue)
    if (this.hasToggleButtonTarget) {
      this.toggleButtonTarget.textContent = this.editingValue ? "Done" : "Edit"
      this.toggleButtonTarget.setAttribute("aria-pressed", String(this.editingValue))
    }
  }
}
