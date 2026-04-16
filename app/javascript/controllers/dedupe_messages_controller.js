import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE && node.id) {
            const existing = this.element.querySelectorAll(`#${CSS.escape(node.id)}`)
            if (existing.length > 1) {
              existing[0].remove()
            }
          }
        }
      }
    })
    this.observer.observe(this.element, { childList: true })
  }

  disconnect() {
    this.observer?.disconnect()
  }
}
