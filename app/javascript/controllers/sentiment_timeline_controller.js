import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas", "snippet", "snippetMeta"]
  static values = { segments: Array }

  connect() {
    this._ro = new ResizeObserver(() => this.draw())
    this._ro.observe(this.element)
    this._mo = new MutationObserver(() => this.draw())
    this._mo.observe(document.documentElement, { attributes: true, attributeFilter: ["class"] })
    requestAnimationFrame(() => this.draw())
  }

  disconnect() {
    this._ro.disconnect()
    this._mo.disconnect()
  }

  segmentsValueChanged() {
    this.draw()
  }

  readCssColor(varName) {
    const raw = getComputedStyle(document.documentElement).getPropertyValue(varName).trim()
    return raw || null
  }

  /** HuggingFace windows use positive / negative / discussion; seeds may use consensus / tension / conflict. */
  colorForSegment(seg) {
    const label = (seg.label ?? "").toString().toLowerCase().trim()
    const score = parseFloat(seg.score)
    const byVar = {
      consensus: "--mi-green",
      positive: "--mi-green",
      discussion: "--mi-teal",
      tension: "--mi-amber",
      conflict: "--mi-red",
      negative: "--mi-red",
    }
    const cssVar = byVar[label]
    if (cssVar) {
      const resolved = this.readCssColor(cssVar)
      if (resolved) return resolved
    }

    if (!Number.isNaN(score)) {
      if (score > 0.15) {
        const g = this.readCssColor("--mi-green")
        if (g) return g
        return "#4caf7d"
      }
      if (score < -0.15) {
        const r = this.readCssColor("--mi-red")
        if (r) return r
        return "#e85d4a"
      }
      const t = this.readCssColor("--mi-teal")
      if (t) return t
      return "#00c7a8"
    }

    const neutral = this.readCssColor("--mi-border")
    if (neutral) return neutral
    return "#5c5c5c"
  }

  cssWidth() {
    const canvas = this.canvasTarget
    const w = canvas.clientWidth || this.element.getBoundingClientRect().width || 320
    return Math.max(w, 120)
  }

  timelineTotal(segs) {
    return segs.reduce((m, s) => Math.max(m, Number(s.window_end) || 0), 0) || 1
  }

  draw() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const segs = this.segmentsValue || []
    if (!segs.length) return

    const dpr = window.devicePixelRatio || 1
    const cssW = this.cssWidth()
    const cssH = canvas.clientHeight || 40
    const w = Math.round(cssW * dpr)
    const h = Math.round(cssH * dpr)
    canvas.width = w
    canvas.height = h
    ctx.clearRect(0, 0, w, h)

    const total = this.timelineTotal(segs)
    let x = 0
    const barH = h
    segs.forEach((seg) => {
      const span = (Number(seg.window_end) - Number(seg.window_start)) || 1
      const cw = Math.max(Math.round(dpr * 2), Math.round((span / total) * w))
      ctx.fillStyle = this.colorForSegment(seg)
      ctx.fillRect(x, 0, cw, barH)
      x += cw
    })
  }

  click(event) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const px = event.clientX - rect.left
    if (px < 0 || px > rect.width) return

    const segs = this.segmentsValue || []
    if (!segs.length) return

    const total = this.timelineTotal(segs)
    let xCss = 0
    for (const seg of segs) {
      const span = (Number(seg.window_end) - Number(seg.window_start)) || 1
      const cw = Math.max(2, (span / total) * rect.width)
      if (px >= xCss && px < xCss + cw) {
        this.showSegmentDetail(seg)
        this.dispatch("focus", { detail: { timestamp: seg.window_start, segment: seg } })
        return
      }
      xCss += cw
    }
  }

  showSegmentDetail(seg) {
    const snippet = (seg.transcript_snippet ?? seg.transcriptSnippet ?? "").toString().trim()
    const start = Number(seg.window_start)
    const end = Number(seg.window_end)
    const label = (seg.label ?? "").toString()
    const meta = `${this.formatClock(start)} – ${this.formatClock(end)}${label ? ` · ${label}` : ""}`

    if (this.hasSnippetMetaTarget) this.snippetMetaTarget.textContent = meta

    if (this.hasSnippetTarget) {
      this.snippetTarget.textContent = snippet || "No transcript text is stored for this window. Re-run sentiment analysis to attach snippets."
      this.snippetTarget.classList.remove("hidden")
    }
  }

  formatClock(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0))
    const m = Math.floor(s / 60)
    const r = s % 60
    return `${m}:${r.toString().padStart(2, "0")}`
  }
}
