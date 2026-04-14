import { Controller } from "@hotwired/stimulus"

// Swaps the visible text of the selected option to a short currency symbol,
// while keeping the full "USD — US Dollar" label available as data-full.
// Expected option markup: <option data-full="USD — US Dollar" data-symbol="$">
export default class extends Controller {
  connect() {
    this.showSymbolForSelected()
  }

  change() {
    this.showSymbolForSelected()
  }

  showSymbolForSelected() {
    const select = this.element
    for (const option of select.options) {
      if (option.dataset.full) {
        option.textContent = option.dataset.full
      }
    }
    const selected = select.options[select.selectedIndex]
    if (selected && selected.dataset.symbol) {
      selected.textContent = selected.dataset.symbol
    }
  }
}
