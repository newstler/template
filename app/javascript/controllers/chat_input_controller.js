import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "form", "fileInput", "attachButton", "attachmentPreview"]

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
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      if (this.textareaTarget.value.trim() || this.selectedFiles.length > 0) {
        this.formTarget.requestSubmit()
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
    // Create or update preview area
    let previewArea = this.element.querySelector('.attachment-preview')
    if (!previewArea) {
      previewArea = document.createElement('div')
      previewArea.className = 'attachment-preview flex flex-wrap gap-2 px-3 pb-2'
      this.element.querySelector('.p-3').after(previewArea)
    }

    previewArea.innerHTML = ''
    this.selectedFiles.forEach((file, index) => {
      const preview = document.createElement('div')
      preview.className = 'flex items-center gap-2 bg-dark-700 rounded-lg px-2 py-1 text-xs text-dark-200'

      const icon = file.type.startsWith('image/') ? '🖼️' : '📄'
      preview.innerHTML = `
        <span>${icon}</span>
        <span class="truncate max-w-[120px]">${file.name}</span>
        <button type="button" class="text-dark-400 hover:text-dark-100" data-index="${index}" data-action="click->chat-input#removeFile">×</button>
      `
      previewArea.appendChild(preview)
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
      const previewArea = this.element.querySelector('.attachment-preview')
      if (previewArea) previewArea.remove()
    } else {
      this.showAttachmentPreview()
    }
  }
}
