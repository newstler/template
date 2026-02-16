import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropzone", "placeholder", "preview", "previewImage", "removeFlag", "spinner"]

  connect() {
    this.form = this.element.closest("form")
    if (this.form) {
      this.submitStart = () => this.showSpinner()
      this.submitEnd = () => this.hideSpinner()
      this.form.addEventListener("turbo:submit-start", this.submitStart)
      this.form.addEventListener("turbo:submit-end", this.submitEnd)
    }
  }

  disconnect() {
    if (this.form) {
      this.form.removeEventListener("turbo:submit-start", this.submitStart)
      this.form.removeEventListener("turbo:submit-end", this.submitEnd)
    }
  }

  showSpinner() {
    if (this.hasSpinnerTarget && this.inputTarget.files.length > 0) {
      this.spinnerTarget.classList.remove("hidden")
    }
  }

  hideSpinner() {
    if (this.hasSpinnerTarget) {
      this.spinnerTarget.classList.add("hidden")
    }
  }

  browse(event) {
    if (event.target.closest("button[data-action*='clear']")) return
    this.inputTarget.click()
  }

  dragover(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.add("border-accent-500")
  }

  dragleave() {
    this.dropzoneTarget.classList.remove("border-accent-500")
  }

  drop(event) {
    event.preventDefault()
    this.dropzoneTarget.classList.remove("border-accent-500")

    const file = event.dataTransfer.files[0]
    if (file && file.type.startsWith("image/")) {
      this.setFile(file)
    }
  }

  inputTargetConnected() {
    this.inputTarget.addEventListener("change", () => {
      const file = this.inputTarget.files[0]
      if (file) this.showPreview(file)
    })
  }

  setFile(file) {
    const dt = new DataTransfer()
    dt.items.add(file)
    this.inputTarget.files = dt.files
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    this.showPreview(file)
  }

  showPreview(file) {
    const reader = new FileReader()
    reader.onload = (e) => {
      this.previewImageTarget.src = e.target.result
      this.placeholderTarget.classList.add("hidden")
      this.previewTarget.classList.remove("hidden")
      if (this.hasRemoveFlagTarget) this.removeFlagTarget.value = "0"
    }
    reader.readAsDataURL(file)
  }

  clear(event) {
    event.stopPropagation()
    this.inputTarget.value = ""
    this.previewTarget.classList.add("hidden")
    this.placeholderTarget.classList.remove("hidden")
    this.previewImageTarget.src = ""
    if (this.hasRemoveFlagTarget) this.removeFlagTarget.value = "1"
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
