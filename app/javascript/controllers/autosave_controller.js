import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status"]

  save() {
    clearTimeout(this._timeout)
    this._timeout = setTimeout(() => this._submit(), 500)
  }

  async _submit() {
    const form = this.element
    const formData = new FormData(form)

    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "Saving..."
      this.statusTarget.classList.remove("hidden")
    }

    try {
      const response = await fetch(form.action, {
        method: form.method === "get" ? "GET" : "POST",
        body: formData,
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      if (this.hasStatusTarget) {
        this.statusTarget.textContent = response.ok ? "Saved" : "Error"
        setTimeout(() => this.statusTarget.classList.add("hidden"), 1500)
      }
    } catch {
      if (this.hasStatusTarget) {
        this.statusTarget.textContent = "Error"
        setTimeout(() => this.statusTarget.classList.add("hidden"), 2000)
      }
    }
  }
}
