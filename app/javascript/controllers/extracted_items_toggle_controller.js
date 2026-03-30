import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabActions", "tabDecisions", "panelActions", "panelDecisions"]

  connect() {
    this.selectActions()
  }

  selectActions() {
    this.panelActionsTarget.classList.remove("hidden")
    this.panelDecisionsTarget.classList.add("hidden")
    this.tabActionsTarget.setAttribute("aria-selected", "true")
    this.tabDecisionsTarget.setAttribute("aria-selected", "false")
    this.tabActionsTarget.classList.add("bg-[var(--mi-surface)]", "text-[var(--mi-text)]", "shadow-sm")
    this.tabActionsTarget.classList.remove("text-[var(--mi-text-secondary)]")
    this.tabDecisionsTarget.classList.remove("bg-[var(--mi-surface)]", "text-[var(--mi-text)]", "shadow-sm")
    this.tabDecisionsTarget.classList.add("text-[var(--mi-text-secondary)]")
  }

  selectDecisions() {
    this.panelActionsTarget.classList.add("hidden")
    this.panelDecisionsTarget.classList.remove("hidden")
    this.tabActionsTarget.setAttribute("aria-selected", "false")
    this.tabDecisionsTarget.setAttribute("aria-selected", "true")
    this.tabDecisionsTarget.classList.add("bg-[var(--mi-surface)]", "text-[var(--mi-text)]", "shadow-sm")
    this.tabDecisionsTarget.classList.remove("text-[var(--mi-text-secondary)]")
    this.tabActionsTarget.classList.remove("bg-[var(--mi-surface)]", "text-[var(--mi-text)]", "shadow-sm")
    this.tabActionsTarget.classList.add("text-[var(--mi-text-secondary)]")
  }
}
