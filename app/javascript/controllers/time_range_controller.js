import { Controller } from "@hotwired/stimulus"

// Posts back a ?range= query param on select change, then navigates via
// Turbo so the dashboard controller picks up the new @range.
//
// Usage:
//   <select data-controller="time-range"
//           data-action="change->time-range#update">
//     <option value="7d">Last 7 days</option>
//     <option value="30d" selected>Last 30 days</option>
//     <option value="90d">Last 90 days</option>
//   </select>
export default class extends Controller {
  update(event) {
    const range = event.target.value
    const url = new URL(window.location.href)
    url.searchParams.set("range", range)
    if (window.Turbo && typeof window.Turbo.visit === "function") {
      window.Turbo.visit(url.toString())
    } else {
      window.location.href = url.toString()
    }
  }
}
