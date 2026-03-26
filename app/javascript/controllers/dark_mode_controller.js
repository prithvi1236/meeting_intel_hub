import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay"]

  connect() {
    const stored = localStorage.getItem("theme")
    if (stored === "light") document.documentElement.classList.remove("dark")
    if (stored === "dark") document.documentElement.classList.add("dark")
  }

  toggle() {
    document.documentElement.classList.toggle("dark")
    localStorage.setItem(
      "theme",
      document.documentElement.classList.contains("dark") ? "dark" : "light"
    )
  }

  toggleNav() {
    if (!this.hasDrawerTarget || !this.hasOverlayTarget) return
    this.drawerTarget.classList.toggle("-translate-x-full")
    this.overlayTarget.classList.toggle("hidden")
  }

  closeNav() {
    if (!this.hasDrawerTarget || !this.hasOverlayTarget) return
    this.drawerTarget.classList.add("-translate-x-full")
    this.overlayTarget.classList.add("hidden")
  }
}
