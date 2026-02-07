import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "available", "taken", "submit"]
  static values = {
    url: String,
    original: String
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  check() {
    if (this.timeout) clearTimeout(this.timeout)

    const name = this.inputTarget.value.trim()

    if (!name) {
      this.hideStatus()
      this.disableSubmit()
      return
    }

    if (name === this.originalValue) {
      this.hideStatus()
      this.enableSubmit()
      return
    }

    this.timeout = setTimeout(() => this.fetchAvailability(name), 300)
  }

  async fetchAvailability(name) {
    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("name", name)

      const response = await fetch(url, {
        headers: { "Accept": "application/json" }
      })
      const data = await response.json()

      if (this.inputTarget.value.trim() !== name) return

      if (data.available) {
        this.showAvailable()
        this.enableSubmit()
      } else {
        this.showTaken()
        this.disableSubmit()
      }
    } catch {
      this.hideStatus()
      this.enableSubmit()
    }
  }

  showAvailable() {
    this.availableTarget.classList.remove("hidden")
    this.takenTarget.classList.add("hidden")
    this.inputTarget.classList.remove("border-red-500", "focus:border-red-500")
    this.inputTarget.classList.add("border-green-500", "focus:border-green-500")
  }

  showTaken() {
    this.takenTarget.classList.remove("hidden")
    this.availableTarget.classList.add("hidden")
    this.inputTarget.classList.remove("border-green-500", "focus:border-green-500")
    this.inputTarget.classList.add("border-red-500", "focus:border-red-500")
  }

  hideStatus() {
    this.availableTarget.classList.add("hidden")
    this.takenTarget.classList.add("hidden")
    this.inputTarget.classList.remove("border-green-500", "focus:border-green-500", "border-red-500", "focus:border-red-500")
  }

  enableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = false
  }

  disableSubmit() {
    if (this.hasSubmitTarget) this.submitTarget.disabled = true
  }
}
