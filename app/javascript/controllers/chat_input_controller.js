import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form", "fileInput", "attachButton", "previewArea", "inputContainer"]

  connect() {
    this.resize()
    this.selectedFiles = []
  }

  resize() {
    const textarea = this.textareaTarget
    textarea.style.height = "auto"
    textarea.style.height = Math.min(textarea.scrollHeight, 200) + "px"
  }

  submit(event) {
    if (event.key === "Enter") {
      if (event.altKey) {
        // Alt/Option+Enter inserts a new line
        event.preventDefault()
        const textarea = this.textareaTarget
        const start = textarea.selectionStart
        const end = textarea.selectionEnd
        const value = textarea.value
        textarea.value = value.substring(0, start) + "\n" + value.substring(end)
        textarea.selectionStart = textarea.selectionEnd = start + 1
        this.resize()
      } else {
        // Enter submits the form
        event.preventDefault()
        if (this.textareaTarget.value.trim() || this.selectedFiles.length > 0) {
          this.formTarget.requestSubmit()
        }
      }
    }
  }

  triggerFileInput() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const files = Array.from(event.target.files)
    if (files.length > 0) {
      this.selectedFiles = files
      this.showAttachmentPreview()
    }
  }

  showAttachmentPreview() {
    // Show the preview area
    this.previewAreaTarget.classList.remove("hidden")
    this.previewAreaTarget.innerHTML = ""

    this.selectedFiles.forEach((file, index) => {
      const preview = document.createElement("div")
      preview.className = "flex items-center gap-2 bg-dark-700 rounded-lg px-2 py-1 text-xs text-dark-200"

      const icon = document.createElement("span")
      icon.textContent = file.type.startsWith("image/") ? "🖼️" : "📄"

      const name = document.createElement("span")
      name.className = "truncate max-w-[120px]"
      name.textContent = file.name

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.className = "text-dark-400 hover:text-dark-100"
      removeBtn.dataset.index = index
      removeBtn.dataset.action = "click->chat-input#removeFile"
      removeBtn.textContent = "×"

      preview.appendChild(icon)
      preview.appendChild(name)
      preview.appendChild(removeBtn)
      this.previewAreaTarget.appendChild(preview)
    })
  }

  removeFile(event) {
    const index = parseInt(event.target.dataset.index)
    this.selectedFiles.splice(index, 1)

    // Update the file input
    const dt = new DataTransfer()
    this.selectedFiles.forEach(file => dt.items.add(file))
    this.fileInputTarget.files = dt.files

    if (this.selectedFiles.length === 0) {
      this.previewAreaTarget.classList.add("hidden")
      this.previewAreaTarget.innerHTML = ""
    } else {
      this.showAttachmentPreview()
    }
  }
}
