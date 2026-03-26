import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["zone", "input", "preview", "error"]
  static classes = ["highlight"]

  connect() {
    this.highlightClassList = (this.highlightClasses.length && this.highlightClasses[0]?.split(" ")) || [
      "border-teal-500",
      "bg-teal-500/10",
    ]
  }

  highlight() {
    this.clearError()
    this.zoneTarget.classList.add(...this.highlightClassList)
  }

  unhighlight() {
    this.zoneTarget.classList.remove(...this.highlightClassList)
  }

  handleDrop(event) {
    event.preventDefault()
    this.unhighlight()
    this.processFiles(event.dataTransfer.files)
  }

  handleSelect(event) {
    this.processFiles(event.target.files)
  }

  processFiles(fileList) {
    this.clearError()
    this.previewTarget.innerHTML = ""
    const files = Array.from(fileList || [])
    const allowed = new Set(["txt", "vtt", "srt"])
    files.forEach((file) => {
      const ext = file.name.split(".").pop()?.toLowerCase()
      if (!allowed.has(ext)) {
        this.showError(`Unsupported type: ${file.name}`)
        return
      }
      this.previewTarget.appendChild(this.renderPreview(file, ext))
    })
    if (this.hasInputTarget && files.length && allowed.has(files[0].name.split(".").pop()?.toLowerCase())) {
      try {
        const dt = new DataTransfer()
        files.forEach((f) => dt.items.add(f))
        this.inputTarget.files = dt.files
      } catch {
        /* older browsers */
      }
    }
  }

  openFilePicker() {
    this.inputTarget.click()
  }

  renderPreview(file, ext) {
    const card = document.createElement("div")
    card.className =
      "flex items-center justify-between rounded-[8px] border border-[var(--mi-border)] bg-[var(--mi-surface)] px-3 py-2 text-sm"
    card.innerHTML = `
      <span class="truncate">${file.name}</span>
      <span class="font-mono-mi text-xs text-[var(--mi-text-secondary)]">.${ext} · ${(file.size / 1024).toFixed(1)} KB</span>
    `
    return card
  }

  showError(msg) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = msg
    this.errorTarget.classList.remove("hidden")
  }

  clearError() {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = ""
    this.errorTarget.classList.add("hidden")
  }
}
