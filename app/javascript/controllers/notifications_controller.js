import { Controller } from "@hotwired/stimulus"

// Marks a notification as read when it's clicked, via a PATCH to
// mark_read_notification_path. The URL is passed in as a Stimulus value.
//
// Usage in the view:
//   data-controller="notifications"
//   data-action="click->notifications#markRead"
//   data-notifications-mark-read-url-value="<%= mark_read_notification_path(n) %>"
export default class extends Controller {
  static values = { markReadUrl: String }

  async markRead(event) {
    // Don't intercept clicks on links inside the notification body —
    // let them navigate normally.
    if (event.target.closest("a")) return

    const response = await fetch(this.markReadUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })

    if (response.ok) {
      const stream = await response.text()
      Turbo.renderStreamMessage(stream)
    }
  }
}
