import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { promote: String, list: String }

  connect() {
    if (this.promoteValue) this.reorder()
  }

  reorder() {
    const list = document.getElementById(this.listValue)
    const item = document.getElementById(`sidebar_conversation_${this.promoteValue}`)
    if (!list || !item || item === list.firstElementChild) return

    const children = [...list.children]
    const before = new Map()
    children.forEach(el => before.set(el, el.getBoundingClientRect()))

    list.prepend(item)

    children.forEach(el => {
      const oldRect = before.get(el)
      const newRect = el.getBoundingClientRect()
      const dy = oldRect.top - newRect.top
      if (Math.abs(dy) > 1) {
        el.animate(
          [{ transform: `translateY(${dy}px)` }, { transform: "translateY(0)" }],
          { duration: 250, easing: "ease-out" }
        )
      }
    })
  }
}
