import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dots"]

  connect() {
    this.observer = new MutationObserver(() => {
      if (this.hasDots && this.element.childNodes.length > 1) {
        this.dotsTarget.remove()
        this.observer.disconnect()
      }
    })

    this.observer.observe(this.element, { childList: true })
  }

  get hasDots() {
    return this.hasDotsTarget
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
