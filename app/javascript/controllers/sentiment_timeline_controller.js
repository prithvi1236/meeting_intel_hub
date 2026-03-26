import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { segments: Array }

  connect() {
    this.draw()
  }

  segmentsValueChanged() {
    this.draw()
  }

  draw() {
    const canvas = this.canvasTarget
    const ctx = canvas.getContext("2d")
    const segs = this.segmentsValue || []
    if (!segs.length) return

    const dpr = window.devicePixelRatio || 1
    const w = (canvas.clientWidth || 320) * dpr
    const h = (canvas.clientHeight || 40) * dpr
    canvas.width = w
    canvas.height = h
    ctx.clearRect(0, 0, w, h)

    const total = segs.reduce((m, s) => Math.max(m, s.window_end || 0), 0) || 1
    let x = 0
    const y = 0
    const barH = h
    segs.forEach((seg) => {
      const span = ((seg.window_end || 0) - (seg.window_start || 0)) || 1
      const cw = Math.max(2, (span / total) * w)
      ctx.fillStyle = this.colorForLabel(seg.label)
      ctx.fillRect(x, y, cw, barH)
      x += cw
    })
  }

  colorForLabel(label) {
    switch (label) {
      case "consensus":
        return "#4caf7d"
      case "discussion":
        return "#00c7a8"
      case "tension":
        return "#f5a623"
      case "conflict":
        return "#e85d4a"
      default:
        return "#2a2a2a"
    }
  }

  click(event) {
    const rect = this.canvasTarget.getBoundingClientRect()
    const px = event.clientX - rect.left
    const frac = px / rect.width
    const segs = this.segmentsValue || []
    const total = segs.reduce((m, s) => Math.max(m, s.window_end || 0), 0) || 1
    const t = frac * total
    let acc = 0
    for (const seg of segs) {
      const span = ((seg.window_end || 0) - (seg.window_start || 0)) || 1
      acc += span
      if (t <= acc) {
        this.dispatch("focus", { detail: { timestamp: seg.window_start } })
        return
      }
    }
  }
}
