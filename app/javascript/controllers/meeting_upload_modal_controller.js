import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

const ROW_GRID_CLASS =
  "grid gap-3 rounded-[10px] border border-[var(--mi-border)] bg-[var(--mi-bg)]/40 p-3 text-sm sm:grid-cols-2"

const DEFAULT_HIGHLIGHT_CLASSES = ["border-teal-500", "bg-teal-500/10"]

const ALLOWED_EXTENSIONS = new Set(["txt", "vtt"])

function escapeHtml(str) {
  const d = document.createElement("div")
  d.textContent = str
  return d.innerHTML
}

function escapeAttr(str) {
  return String(str)
    .replace(/&/g, "&amp;")
    .replace(/"/g, "&quot;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
}

export default class extends Controller {
  static targets = ["dialog", "dropZone", "fileInput", "rows", "saveButton", "errorBox"]
  static values = {
    previewUrl: String,
    importUrl: String,
    group: String,
    groupSort: String,
    open: Boolean,
  }
  static classes = ["highlight"]

  connect() {
    this.fileRows = []
    this.highlightClassList =
      (this.highlightClasses.length && this.highlightClasses[0]?.split(" ")) || DEFAULT_HIGHLIGHT_CLASSES
    if (this.openValue) this.dialogTarget.showModal()
  }

  openModal() {
    this.dialogTarget.showModal()
  }

  closeModal() {
    this.dialogTarget.close()
    this.resetState()
  }

  resetState() {
    this.fileRows = []
    this.rowsTarget.innerHTML = ""
    this.fileInputTarget.value = ""
    this.clearClientError()
    this.toggleSave(false)
  }

  browse() {
    this.fileInputTarget.click()
  }

  highlight(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add(...this.highlightClassList)
  }

  unhighlight() {
    this.dropZoneTarget.classList.remove(...this.highlightClassList)
  }

  handleDrop(event) {
    event.preventDefault()
    this.unhighlight()
    this.addFiles(event.dataTransfer.files)
  }

  handleFileSelect(event) {
    this.addFiles(event.target.files)
    this.fileInputTarget.value = ""
  }

  async addFiles(fileList) {
    const files = Array.from(fileList || [])
    for (const file of files) {
      const ext = file.name.split(".").pop()?.toLowerCase()
      if (!ALLOWED_EXTENSIONS.has(ext)) {
        this.showClientError(`Unsupported type (${file.name}). Use .txt or .vtt only.`)
        continue
      }
      await this.previewAndAppendRow(file)
    }
  }

  async previewAndAppendRow(file) {
    const data = await this.fetchPreviewJson(file)
    if (!data) return

    const index = this.fileRows.length
    this.fileRows.push({
      file,
      suggestedTitle: data.suggested_title,
      detectedDate: data.detected_meeting_date || "",
      wordCount: data.word_count,
      speakerCount: data.speaker_count,
      fileName: data.file_name,
    })
    this.appendRowElement(index)
    this.clearClientError()
    this.toggleSave(true)
  }

  async fetchPreviewJson(file) {
    const fd = new FormData()
    fd.append("transcript_file", file)
    fd.append("authenticity_token", this.csrfToken)

    try {
      const res = await fetch(this.previewUrlValue, {
        method: "POST",
        body: fd,
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken,
        },
      })
      const data = await res.json()
      if (!res.ok) {
        this.showClientError(data.error || "Could not preview file.")
        return null
      }
      return data
    } catch {
      this.showClientError("Network error while previewing.")
      return null
    }
  }

  appendRowElement(index) {
    const row = this.fileRows[index]
    const tr = document.createElement("div")
    tr.className = ROW_GRID_CLASS
    tr.setAttribute("data-row-index", String(index))
    tr.innerHTML = this.rowInnerHtml(row, index)
    this.rowsTarget.appendChild(tr)
  }

  rowInnerHtml(row, index) {
    const dateNote = row.detectedDate
      ? ` · Detected date: ${escapeHtml(row.detectedDate)}`
      : ""
    return `
      <div class="sm:col-span-2 flex flex-wrap items-start justify-between gap-2">
        <div class="min-w-0">
          <p class="text-xs font-mono-mi uppercase text-[var(--mi-text-secondary)]">File</p>
          <p class="mt-0.5 truncate font-medium" title="${escapeHtml(row.fileName)}">${escapeHtml(row.fileName)}</p>
        </div>
        <button type="button" class="shrink-0 rounded-[6px] border border-[var(--mi-border)] px-2 py-1 text-xs" data-action="click->meeting-upload-modal#removeRow" data-row-index="${index}">
          Remove
        </button>
      </div>
      <div>
        <label class="block text-xs text-[var(--mi-text-secondary)]">Meeting name</label>
        <input type="text" name="title" value="${escapeAttr(row.suggestedTitle)}" class="mt-1 w-full rounded-[8px] border border-[var(--mi-border)] bg-[var(--mi-surface)] px-2 py-1.5 text-sm" data-field="title" />
      </div>
      <div>
        <label class="block text-xs text-[var(--mi-text-secondary)]">Meeting date</label>
        <input type="date" name="meeting_date" value="${escapeAttr(row.detectedDate)}" class="mt-1 w-full rounded-[8px] border border-[var(--mi-border)] bg-[var(--mi-surface)] px-2 py-1.5 text-sm" data-field="date" />
      </div>
      <div class="sm:col-span-2 text-xs font-mono-mi text-[var(--mi-text-secondary)]">
        ${Number(row.wordCount).toLocaleString()} words · ${Number(row.speakerCount)} speakers${dateNote}
      </div>
    `
  }

  removeRow(event) {
    const idx = parseInt(event.currentTarget.dataset.rowIndex, 10)
    if (Number.isNaN(idx)) return
    this.fileRows.splice(idx, 1)
    this.rebuildRows()
  }

  rebuildRows() {
    this.rowsTarget.innerHTML = ""
    const next = [...this.fileRows]
    this.fileRows = []
    next.forEach((row) => {
      this.fileRows.push(row)
      this.appendRowElement(this.fileRows.length - 1)
    })
    this.toggleSave(this.fileRows.length > 0)
  }

  async save(event) {
    event?.preventDefault()
    if (this.fileRows.length === 0) return

    const fd = this.buildImportFormData()

    try {
      const res = await fetch(this.importUrlValue, {
        method: "POST",
        body: fd,
        headers: {
          Accept: "text/vnd.turbo-stream.html",
          "X-CSRF-Token": this.csrfToken,
        },
      })
      const text = await res.text()
      Turbo.renderStreamMessage(text)
      if (res.ok) {
        this.closeModal()
      }
    } catch {
      this.showClientError("Network error while saving.")
    }
  }

  buildImportFormData() {
    const fd = new FormData()
    fd.append("authenticity_token", this.csrfToken)
    fd.append("group", this.groupValue)
    fd.append("group_sort", this.groupSortValue)

    this.fileRows.forEach((row, i) => {
      const el = this.rowsTarget.querySelector(`[data-row-index="${i}"]`)
      if (!el) return
      const title = el.querySelector('[data-field="title"]')?.value ?? row.suggestedTitle
      const date = el.querySelector('[data-field="date"]')?.value ?? ""
      fd.append(`meeting_imports[${i}][title]`, title)
      fd.append(`meeting_imports[${i}][meeting_date]`, date)
      fd.append(`meeting_imports[${i}][file]`, row.file, row.file.name)
    })
    return fd
  }

  toggleSave(enabled) {
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.disabled = !enabled
    }
  }

  showClientError(msg) {
    if (this.hasErrorBoxTarget) {
      this.errorBoxTarget.textContent = msg
      this.errorBoxTarget.classList.remove("hidden")
    }
  }

  clearClientError() {
    if (this.hasErrorBoxTarget) {
      this.errorBoxTarget.textContent = ""
      this.errorBoxTarget.classList.add("hidden")
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute("content") || ""
  }
}
