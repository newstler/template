import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.resize()
  }

  resize() {
    const tempSpan = document.createElement("span")
    tempSpan.style.visibility = "hidden"
    tempSpan.style.position = "absolute"
    tempSpan.style.whiteSpace = "nowrap"
    tempSpan.style.font = window.getComputedStyle(this.element).font
    tempSpan.textContent = this.element.options[this.element.selectedIndex]?.text || ""
    document.body.appendChild(tempSpan)

    const textWidth = tempSpan.offsetWidth
    document.body.removeChild(tempSpan)

    // Add padding for the chevron icon and some buffer
    this.element.style.width = `${textWidth + 32}px`
  }
}
