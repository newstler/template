import { Controller } from "@hotwired/stimulus"

// Themes a Chartkick-produced Chart.js canvas to match the app's
// OKLCH dark theme. Waits up to ~2 seconds for the Chartkick canvas
// to mount before giving up. Generalized from sailing_plus's
// revenue_chart_controller.js without any currency formatting.
export default class extends Controller {
  connect() {
    this.disconnected = false
    this.findChart(0)
  }

  disconnect() {
    this.disconnected = true
  }

  findChart(attempt) {
    if (this.disconnected) return

    const canvas = this.element.querySelector("canvas")
    if (!canvas || !window.Chartkick) {
      if (attempt < 20) setTimeout(() => this.findChart(attempt + 1), 100)
      return
    }

    const chartkickChart = Object.values(Chartkick.charts).find((c) => {
      return this.element.contains(c.element)
    })

    if (!chartkickChart || !chartkickChart.chart) {
      if (attempt < 20) setTimeout(() => this.findChart(attempt + 1), 100)
      return
    }

    const chart = chartkickChart.chart

    // Theme line datasets for the dark OKLCH palette.
    chart.data.datasets.forEach((ds) => {
      if (ds.type === "line" || !ds.type) {
        ds.order = 0
      } else {
        ds.borderWidth = 0
        ds.hoverBackgroundColor = ds.backgroundColor
        ds.order = 2
      }
    })

    if (chart.options.scales && chart.options.scales.y && chart.options.scales.y.grid) {
      const yGrid = chart.options.scales.y.grid
      yGrid.color = (context) => {
        return context.tick.value === 0
          ? "oklch(55% 0.01 250)"
          : "oklch(25% 0.01 250)"
      }
      yGrid.lineWidth = (context) => {
        return context.tick.value === 0 ? 2 : 1
      }
    }

    if (chart.options.scales && chart.options.scales.x && chart.options.scales.x.grid) {
      chart.options.scales.x.grid.display = false
    }

    chart.update("none")
  }
}
