import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "overlay", "content", "navGroup"]
  static values = {
    open: { type: Boolean, default: false },
    collapsed: { type: Array, default: [] }
  }

  connect() {
    this.loadCollapsedState()
    this.checkMobileView()
    window.addEventListener("resize", this.handleResize.bind(this))
  }

  disconnect() {
    window.removeEventListener("resize", this.handleResize.bind(this))
  }

  toggle() {
    this.openValue = !this.openValue
    this.updateSidebarVisibility()
  }

  open() {
    this.openValue = true
    this.updateSidebarVisibility()
  }

  close() {
    this.openValue = false
    this.updateSidebarVisibility()
  }

  updateSidebarVisibility() {
    if (this.hasSidebarTarget) {
      if (this.openValue) {
        this.sidebarTarget.classList.remove("-translate-x-full")
        this.sidebarTarget.classList.add("translate-x-0")
      } else {
        this.sidebarTarget.classList.add("-translate-x-full")
        this.sidebarTarget.classList.remove("translate-x-0")
      }
    }

    if (this.hasOverlayTarget) {
      if (this.openValue) {
        this.overlayTarget.classList.remove("hidden")
        this.overlayTarget.classList.add("block")
      } else {
        this.overlayTarget.classList.add("hidden")
        this.overlayTarget.classList.remove("block")
      }
    }
  }

  toggleGroup(event) {
    const groupId = event.currentTarget.dataset.groupId
    const groupContent = document.getElementById(`nav-group-${groupId}`)
    const chevron = event.currentTarget.querySelector("[data-chevron]")

    if (!groupContent) return

    const isCollapsed = groupContent.classList.contains("hidden")

    if (isCollapsed) {
      groupContent.classList.remove("hidden")
      chevron?.classList.add("rotate-90")
      this.removeFromCollapsed(groupId)
    } else {
      groupContent.classList.add("hidden")
      chevron?.classList.remove("rotate-90")
      this.addToCollapsed(groupId)
    }

    this.saveCollapsedState()
  }

  loadCollapsedState() {
    try {
      const saved = localStorage.getItem("sidebar-collapsed-groups")
      if (saved) {
        this.collapsedValue = JSON.parse(saved)
        this.applyCollapsedState()
      }
    } catch (e) {
      console.warn("Could not load sidebar state:", e)
    }
  }

  saveCollapsedState() {
    try {
      localStorage.setItem("sidebar-collapsed-groups", JSON.stringify(this.collapsedValue))
    } catch (e) {
      console.warn("Could not save sidebar state:", e)
    }
  }

  applyCollapsedState() {
    this.collapsedValue.forEach(groupId => {
      const groupContent = document.getElementById(`nav-group-${groupId}`)
      const trigger = document.querySelector(`[data-group-id="${groupId}"]`)
      const chevron = trigger?.querySelector("[data-chevron]")

      if (groupContent) {
        groupContent.classList.add("hidden")
      }
      if (chevron) {
        chevron.classList.remove("rotate-90")
      }
    })
  }

  addToCollapsed(groupId) {
    if (!this.collapsedValue.includes(groupId)) {
      this.collapsedValue = [...this.collapsedValue, groupId]
    }
  }

  removeFromCollapsed(groupId) {
    this.collapsedValue = this.collapsedValue.filter(id => id !== groupId)
  }

  handleResize() {
    this.checkMobileView()
  }

  checkMobileView() {
    const isMobile = window.innerWidth < 1024
    if (!isMobile && this.hasSidebarTarget) {
      this.sidebarTarget.classList.remove("-translate-x-full")
      this.sidebarTarget.classList.add("translate-x-0")
      if (this.hasOverlayTarget) {
        this.overlayTarget.classList.add("hidden")
      }
    } else if (isMobile && !this.openValue && this.hasSidebarTarget) {
      this.sidebarTarget.classList.add("-translate-x-full")
      this.sidebarTarget.classList.remove("translate-x-0")
    }
  }
}
