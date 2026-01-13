import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form"]

  connect() {
    this.resize()
  }

  resize() {
    const textarea = this.textareaTarget
    textarea.style.height = "auto"
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + "px"
  }

  submit(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.textareaTarget.value.trim()) {
        this.formTarget.requestSubmit()
      }
    }
  }
}
