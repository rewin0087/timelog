import { Controller } from "@hotwired/stimulus"

// Mobile account menu (skins + sign out). On desktop the toggle is hidden and the panel is always shown.
export default class extends Controller {
  static targets = ["button"]

  toggle() {
    this.#set(!this.element.classList.contains("open"))
  }

  close() {
    this.#set(false)
  }

  outside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  #set(open) {
    this.element.classList.toggle("open", open)
    this.buttonTarget.setAttribute("aria-expanded", open)
  }
}
