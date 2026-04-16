import { Controller } from "@hotwired/stimulus"

// Chat scroll behavior for conversation threads.
// - Scrolls to bottom on connect and when new messages arrive near the bottom.
// - Infinite-loads older messages when a sentinel enters the viewport.
export default class extends Controller {
  static targets = ["messages", "sentinel"]
  static values = {
    url: String,
    hasOlder: Boolean,
    oldestId: String
  }

  connect() {
    this.loading = false
    this.scrollToBottom()
    this.observeNewMessages()
    this.observeImageLoads()

    if (this.hasOlderValue && this.hasSentinelTarget) {
      this.setupIntersectionObserver()
    }
  }

  disconnect() {
    this.mutationObserver?.disconnect()
    this.intersectionObserver?.disconnect()
  }

  observeNewMessages() {
    this.mutationObserver = new MutationObserver(() => {
      if (this.isNearBottom()) {
        this.scrollToBottom()
      }
      this.observeImageLoads()
    })
    this.mutationObserver.observe(this.messagesTarget, { childList: true, subtree: true })
  }

  observeImageLoads() {
    this.element.querySelectorAll("img:not([data-scroll-observed])").forEach(img => {
      img.dataset.scrollObserved = "true"
      if (!img.complete) {
        img.addEventListener("load", () => {
          if (this.isNearBottom()) this.scrollToBottom()
        }, { once: true })
      }
    })
  }

  isNearBottom() {
    return this.element.scrollHeight - this.element.scrollTop - this.element.clientHeight < 100
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.element.scrollTop = this.element.scrollHeight
    })
  }

  setupIntersectionObserver() {
    this.intersectionObserver = new IntersectionObserver((entries) => {
      const entry = entries[0]
      if (entry.isIntersecting && this.hasOlderValue && !this.loading) {
        this.loadOlder()
      }
    }, { root: this.element, threshold: 0.1 })

    this.intersectionObserver.observe(this.sentinelTarget)
  }

  async loadOlder() {
    this.loading = true
    this.sentinelTarget.classList.remove("hidden")

    const oldScrollHeight = this.element.scrollHeight

    try {
      const separator = this.urlValue.includes("?") ? "&" : "?"
      const response = await fetch(`${this.urlValue}${separator}before=${this.oldestIdValue}`, {
        headers: { "Accept": "text/html" }
      })

      if (!response.ok) return

      const html = await response.text()
      const hasOlder = response.headers.get("X-Has-Older") === "true"
      const oldestId = response.headers.get("X-Oldest-Id")

      if (html.trim()) {
        this.messagesTarget.insertAdjacentHTML("afterbegin", html)

        requestAnimationFrame(() => {
          const newScrollHeight = this.element.scrollHeight
          this.element.scrollTop = newScrollHeight - oldScrollHeight
        })
      }

      this.hasOlderValue = hasOlder
      this.oldestIdValue = oldestId || ""

      if (!hasOlder) {
        this.sentinelTarget.classList.add("hidden")
        this.intersectionObserver?.disconnect()
      }
    } finally {
      this.loading = false
    }
  }
}
