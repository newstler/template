import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "value", "fill"]

  connect() {
    this.update()
  }

  update() {
    const input = this.inputTarget
    const min = parseFloat(input.min)
    const max = parseFloat(input.max)
    const val = parseFloat(input.value)
    const pct = ((val - min) / (max - min)) * 100

    this.valueTarget.textContent = input.step && parseFloat(input.step) < 1
      ? val.toFixed(2)
      : val

    this.fillTarget.style.width = `${pct}%`
  }
}
