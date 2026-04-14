import { Controller } from "@hotwired/stimulus"

// Simple client-side filter on a country options list. Hides non-matching
// options as the user types in the filter input.
export default class extends Controller {
  static targets = ["filter", "select"]

  filter() {
    const query = this.filterTarget.value.toLowerCase()
    Array.from(this.selectTarget.options).forEach((option) => {
      const text = option.text.toLowerCase()
      option.hidden = query.length > 0 && !text.includes(query)
    })
  }
}
