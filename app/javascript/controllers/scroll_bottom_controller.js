import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scrollToBottom()
    this.observeNewMessages()
    this.observeImageLoads()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  observeNewMessages() {
    this.observer = new MutationObserver((mutations) => {
      const hasNewElements = mutations.some(m =>
        m.type === "childList" && [...m.addedNodes].some(n => n.nodeType === Node.ELEMENT_NODE)
      )
      if (hasNewElements) {
        this.scrollToBottom()
        this.observeImageLoads()
      }
    })

    this.observer.observe(this.element, {
      childList: true,
      subtree: true
    })
  }

  observeImageLoads() {
    this.element.querySelectorAll("img:not([data-scroll-observed])").forEach(img => {
      img.dataset.scrollObserved = "true"
      if (!img.complete) {
        img.addEventListener("load", () => this.scrollToBottom(), { once: true })
      }
    })
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }
}
