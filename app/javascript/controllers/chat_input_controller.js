import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form", "fileInput", "attachButton", "previewArea", "inputContainer"]

  connect() {
    this.resize()
    this.selectedFiles = []
    this.textareaTarget.focus()
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
          this.scrollToBottom()
        }
      }
    }
  }

  triggerFileInput() {
    if (this.hasFileInputTarget) {
      this.fileInputTarget.click()
    }
  }

  handleFileSelect(event) {
    const newFiles = Array.from(event.target.files)
    if (newFiles.length > 0) {
      this.selectedFiles = [...this.selectedFiles, ...newFiles]
      this.syncFileInput()
      this.showAttachmentPreview()
    }
  }

  syncFileInput() {
    if (this.hasFileInputTarget) {
      const dt = new DataTransfer()
      this.selectedFiles.forEach(file => dt.items.add(file))
      this.fileInputTarget.files = dt.files
    }
  }

  showAttachmentPreview() {
    if (!this.hasPreviewAreaTarget) return

    this.previewAreaTarget.classList.remove("hidden")
    this.previewAreaTarget.replaceChildren()

    this.selectedFiles.forEach((file, index) => {
      const preview = document.createElement("div")
      preview.className = "relative group w-16 h-16"

      if (file.type.startsWith("image/")) {
        const img = document.createElement("img")
        img.className = "w-16 h-16 object-cover rounded-lg"
        img.src = URL.createObjectURL(file)
        img.onload = () => URL.revokeObjectURL(img.src)
        preview.appendChild(img)
      } else {
        const container = document.createElement("div")
        container.className = "w-16 h-16 bg-dark-700 rounded-lg flex flex-col items-center justify-center"
        const ext = file.name.split('.').pop()?.toUpperCase() || 'FILE'
        const icon = document.createElement("span")
        icon.className = "text-lg"
        icon.textContent = file.type === "application/pdf" ? "📕" : "📄"
        const label = document.createElement("span")
        label.className = "text-[9px] text-dark-400 truncate w-full text-center px-1"
        label.textContent = ext
        container.appendChild(icon)
        container.appendChild(label)
        preview.appendChild(container)
      }

      const removeBtn = document.createElement("button")
      removeBtn.type = "button"
      removeBtn.className = "absolute -top-1 -right-1 w-5 h-5 bg-dark-600 hover:bg-dark-500 text-dark-200 rounded-full flex items-center justify-center text-xs opacity-0 group-hover:opacity-100 transition-opacity"
      removeBtn.dataset.index = index
      removeBtn.dataset.action = "click->chat-input#removeFile"
      removeBtn.textContent = "×"
      preview.appendChild(removeBtn)

      this.previewAreaTarget.appendChild(preview)
    })
  }

  scrollToBottom() {
    const scrollContainer = document.querySelector('[data-controller="scroll-bottom"]')
    if (scrollContainer) {
      scrollContainer.scrollTop = scrollContainer.scrollHeight
    }
  }

  removeFile(event) {
    const index = parseInt(event.target.dataset.index)
    this.selectedFiles.splice(index, 1)
    this.syncFileInput()

    if (this.selectedFiles.length === 0 && this.hasPreviewAreaTarget) {
      this.previewAreaTarget.classList.add("hidden")
      this.previewAreaTarget.replaceChildren()
    } else {
      this.showAttachmentPreview()
    }
  }
}
