import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    filename: String,
    type: String
  }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    const overlay = document.createElement("div")
    overlay.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/90"
    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) this.close()
    })

    const container = document.createElement("div")
    container.className = "relative max-w-[90vw] max-h-[90vh] flex flex-col"
    container.addEventListener("click", (e) => e.stopPropagation())

    if (this.typeValue === "image") {
      const img = document.createElement("img")
      img.src = this.urlValue
      img.className = "max-w-full max-h-[calc(90vh-60px)] object-contain rounded-lg"
      img.alt = this.filenameValue
      container.appendChild(img)
    } else {
      const preview = document.createElement("div")
      preview.className = "bg-dark-800 rounded-lg p-8 flex flex-col items-center gap-4 min-w-[300px]"
      const icon = document.createElement("span")
      icon.className = "text-6xl"
      icon.textContent = this.typeValue === "pdf" || this.filenameValue.endsWith(".pdf") ? "📕" : "📄"
      const name = document.createElement("span")
      name.className = "text-dark-200 text-lg font-medium text-center"
      name.textContent = this.filenameValue
      preview.appendChild(icon)
      preview.appendChild(name)
      container.appendChild(preview)
    }

    const toolbar = document.createElement("div")
    toolbar.className = "flex items-center justify-center gap-4 mt-4"

    const downloadBtn = document.createElement("a")
    downloadBtn.href = this.urlValue
    downloadBtn.download = this.filenameValue
    downloadBtn.className = "flex items-center gap-2 bg-dark-700 hover:bg-dark-600 text-white px-4 py-2 rounded-lg transition-colors"
    const downloadIcon = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    downloadIcon.setAttribute("class", "w-5 h-5")
    downloadIcon.setAttribute("fill", "none")
    downloadIcon.setAttribute("stroke", "currentColor")
    downloadIcon.setAttribute("viewBox", "0 0 24 24")
    const downloadPath = document.createElementNS("http://www.w3.org/2000/svg", "path")
    downloadPath.setAttribute("stroke-linecap", "round")
    downloadPath.setAttribute("stroke-linejoin", "round")
    downloadPath.setAttribute("stroke-width", "2")
    downloadPath.setAttribute("d", "M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4")
    downloadIcon.appendChild(downloadPath)
    downloadBtn.appendChild(downloadIcon)
    downloadBtn.appendChild(document.createTextNode(" Download"))
    toolbar.appendChild(downloadBtn)

    const closeBtn = document.createElement("button")
    closeBtn.type = "button"
    closeBtn.className = "flex items-center gap-2 bg-dark-700 hover:bg-dark-600 text-white px-4 py-2 rounded-lg transition-colors"
    const closeIcon = document.createElementNS("http://www.w3.org/2000/svg", "svg")
    closeIcon.setAttribute("class", "w-5 h-5")
    closeIcon.setAttribute("fill", "none")
    closeIcon.setAttribute("stroke", "currentColor")
    closeIcon.setAttribute("viewBox", "0 0 24 24")
    const closePath = document.createElementNS("http://www.w3.org/2000/svg", "path")
    closePath.setAttribute("stroke-linecap", "round")
    closePath.setAttribute("stroke-linejoin", "round")
    closePath.setAttribute("stroke-width", "2")
    closePath.setAttribute("d", "M6 18L18 6M6 6l12 12")
    closeIcon.appendChild(closePath)
    closeBtn.appendChild(closeIcon)
    closeBtn.appendChild(document.createTextNode(" Close"))
    closeBtn.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.close()
    })
    toolbar.appendChild(closeBtn)

    container.appendChild(toolbar)
    overlay.appendChild(container)
    document.body.appendChild(overlay)
    this.overlay = overlay

    document.addEventListener("keydown", this.handleKeydown)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") {
      this.close()
    }
  }

  close() {
    if (this.overlay) {
      this.overlay.remove()
      this.overlay = null
      document.removeEventListener("keydown", this.handleKeydown)
    }
  }

  disconnect() {
    this.close()
  }
}
