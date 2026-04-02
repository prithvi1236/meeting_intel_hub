import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay", "sunIcon", "moonIcon"]

  connect() {
    const storedTheme = localStorage.getItem("theme")
    if (storedTheme === "light" || storedTheme === "dark") {
      document.documentElement.classList.toggle("dark", storedTheme === "dark")
    }
    this.updateThemeIcon()
  }

  toggle() {
    document.documentElement.classList.toggle("dark")
    localStorage.setItem(
      "theme",
      document.documentElement.classList.contains("dark") ? "dark" : "light"
    )
    this.updateThemeIcon()
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

  updateThemeIcon() {
    if (!this.hasSunIconTarget || !this.hasMoonIconTarget) return

    const isDark = document.documentElement.classList.contains("dark")
    this.sunIconTarget.classList.toggle("hidden", isDark)
    this.moonIconTarget.classList.toggle("hidden", !isDark)
  }
}
