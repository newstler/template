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
    this.observer = new MutationObserver(() => {
      this.scrollToBottom()
      this.observeImageLoads()
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
