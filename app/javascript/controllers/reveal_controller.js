import { Controller } from "@hotwired/stimulus"

// Masks sensitive values (e.g. invoice amounts) until the eye button is pressed.
// Each [data-reveal-target="item"] toggles on its own; toggleAll (any "all" button) flips every item at once.
export default class extends Controller {
  static targets = ["item", "all"]

  connect() {
    this.hideBeforeCache = () => this.#setAll(false)
    document.addEventListener("turbo:before-cache", this.hideBeforeCache)
    this.#setAll(false)
  }

  disconnect() {
    document.removeEventListener("turbo:before-cache", this.hideBeforeCache)
  }

  toggle(event) {
    const item = event.currentTarget.closest("[data-reveal-target~='item']")
    this.#set(item, !item.classList.contains("revealed"))
    this.#syncAll()
  }

  toggleAll() {
    this.#setAll(!this.itemTargets.every((item) => item.classList.contains("revealed")))
  }

  #setAll(shown) {
    this.itemTargets.forEach((item) => this.#set(item, shown))
    this.#syncAll()
  }

  #set(item, shown) {
    item.classList.toggle("revealed", shown)
    const button = item.querySelector("button")
    button?.setAttribute("aria-pressed", shown)
    button?.setAttribute("aria-label", shown ? "Hide amount" : "Show amount")
  }

  #syncAll() {
    const shown = this.itemTargets.length > 0 && this.itemTargets.every((item) => item.classList.contains("revealed"))
    this.allTargets.forEach((button) => {
      button.classList.toggle("revealed", shown)
      button.setAttribute("aria-pressed", shown)
      button.setAttribute("aria-label", shown ? "Hide all amounts" : "Show all amounts")
    })
  }
}
