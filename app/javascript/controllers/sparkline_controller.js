import { Controller } from "@hotwired/stimulus"

// Generic sparkline controller. Attaches a hover tooltip to an inline SVG
// polyline rendered via the DashboardHelper#sparkline helper. Optional:
// pass a data-sparkline-data-value JSON array of { date, value } entries
// to enable the tooltip.
export default class extends Controller {
  static targets = ["svg", "tooltip"]
  static values = { data: Array }

  connect() {
    this.hideTooltip()
  }

  move(event) {
    if (!this.hasSvgTarget || !this.hasTooltipTarget) return
    if (!this.dataValue || this.dataValue.length === 0) return

    const svg = this.svgTarget
    const rect = svg.getBoundingClientRect()
    const x = event.clientX - rect.left
    const ratio = x / rect.width
    const index = Math.round(ratio * (this.dataValue.length - 1))
    const clamped = Math.max(0, Math.min(index, this.dataValue.length - 1))
    const entry = this.dataValue[clamped]
    if (!entry) return

    const tooltip = this.tooltipTarget
    tooltip.textContent = `${entry.date}: ${entry.value}`
    tooltip.classList.remove("hidden")

    const tooltipWidth = tooltip.offsetWidth
    let left = x - tooltipWidth / 2
    left = Math.max(0, Math.min(left, rect.width - tooltipWidth))
    tooltip.style.left = `${left}px`
  }

  leave() {
    this.hideTooltip()
  }

  hideTooltip() {
    if (this.hasTooltipTarget) {
      this.tooltipTarget.classList.add("hidden")
    }
  }
}
