import { Controller } from "@hotwired/stimulus"

const GOOGLE_VIEWER = "https://docs.google.com/gview?embedded=true&url="

const PREVIEWABLE_EXTENSIONS = new Set([
  ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".rtf", ".csv", ".tsv",
])

function svgIcon(d) {
  const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg")
  svg.setAttribute("class", "w-4 h-4")
  svg.setAttribute("fill", "none")
  svg.setAttribute("stroke", "currentColor")
  svg.setAttribute("viewBox", "0 0 24 24")
  const path = document.createElementNS("http://www.w3.org/2000/svg", "path")
  path.setAttribute("stroke-linecap", "round")
  path.setAttribute("stroke-linejoin", "round")
  path.setAttribute("stroke-width", "2")
  path.setAttribute("d", d)
  svg.appendChild(path)
  return svg
}

export default class extends Controller {
  static values = { url: String, filename: String, type: String, contentType: String }

  open(event) {
    event.preventDefault()
    event.stopPropagation()

    this.overlay = this.buildOverlay()

    if (this.typeValue === "image") {
      this.showImage()
    } else if (this.isPreviewable) {
      this.showIframe(GOOGLE_VIEWER + encodeURIComponent(this.absoluteUrl))
    } else {
      this.showGenericFile()
    }

    document.body.appendChild(this.overlay)
    document.addEventListener("keydown", this.handleKeydown)
  }

  get absoluteUrl() {
    return new URL(this.urlValue, window.location.origin).href
  }

  get isPreviewable() {
    const ext = "." + this.filenameValue.split(".").pop().toLowerCase()
    return PREVIEWABLE_EXTENSIONS.has(ext)
  }

  buildOverlay() {
    const overlay = document.createElement("div")
    overlay.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/90"
    overlay.addEventListener("click", (e) => { if (e.target === overlay) this.close() })
    return overlay
  }

  buildContainer(wide = false) {
    const container = document.createElement("div")
    container.className = wide
      ? "relative w-[95vw] max-w-5xl h-[90vh] flex flex-col"
      : "relative max-w-[90vw] max-h-[90vh] flex flex-col"
    container.addEventListener("click", (e) => e.stopPropagation())
    return container
  }

  buildToolbar() {
    const toolbar = document.createElement("div")
    toolbar.className = "flex items-center justify-center gap-3 mt-3 shrink-0"

    const downloadBtn = document.createElement("a")
    downloadBtn.href = this.urlValue
    downloadBtn.download = this.filenameValue
    downloadBtn.className = "flex items-center gap-2 bg-dark-700 hover:bg-dark-600 text-white px-3 py-1.5 rounded-lg text-sm transition-colors"
    downloadBtn.appendChild(svgIcon("M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"))
    downloadBtn.appendChild(document.createTextNode(" Download"))
    toolbar.appendChild(downloadBtn)

    const closeBtn = document.createElement("button")
    closeBtn.type = "button"
    closeBtn.className = "flex items-center gap-2 bg-dark-700 hover:bg-dark-600 text-white px-3 py-1.5 rounded-lg text-sm transition-colors"
    closeBtn.appendChild(svgIcon("M6 18L18 6M6 6l12 12"))
    closeBtn.appendChild(document.createTextNode(" Close"))
    closeBtn.addEventListener("click", (e) => { e.preventDefault(); e.stopPropagation(); this.close() })
    toolbar.appendChild(closeBtn)

    return toolbar
  }

  showImage() {
    const container = this.buildContainer()
    const img = document.createElement("img")
    img.src = this.urlValue
    img.className = "max-w-full max-h-[calc(90vh-60px)] object-contain rounded-lg"
    img.alt = this.filenameValue
    container.appendChild(img)
    container.appendChild(this.buildToolbar())
    this.overlay.appendChild(container)
  }

  showIframe(src) {
    const container = this.buildContainer(true)
    const iframe = document.createElement("iframe")
    iframe.src = src
    iframe.className = "flex-1 w-full rounded-lg bg-white"
    iframe.setAttribute("frameborder", "0")
    iframe.setAttribute("allowfullscreen", "true")
    container.appendChild(iframe)
    container.appendChild(this.buildToolbar())
    this.overlay.appendChild(container)
  }

  showGenericFile() {
    const container = this.buildContainer()
    const preview = document.createElement("div")
    preview.className = "bg-dark-800 rounded-lg p-8 flex flex-col items-center gap-4 min-w-[300px]"
    const icon = document.createElement("span")
    icon.className = "text-6xl"
    icon.textContent = "\u{1F4C4}"
    const name = document.createElement("span")
    name.className = "text-dark-200 text-lg font-medium text-center"
    name.textContent = this.filenameValue
    preview.appendChild(icon)
    preview.appendChild(name)
    container.appendChild(preview)
    container.appendChild(this.buildToolbar())
    this.overlay.appendChild(container)
  }

  handleKeydown = (event) => {
    if (event.key === "Escape") this.close()
  }

  close() {
    if (this.overlay) {
      this.overlay.remove()
      this.overlay = null
      document.removeEventListener("keydown", this.handleKeydown)
    }
  }

  disconnect() { this.close() }
}
