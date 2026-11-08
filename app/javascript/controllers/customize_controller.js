import { Controller } from "@hotwired/stimulus"

// "Customize" section: shows the "Customized" badge when any field inside differs from its value on page load
// (including added extra item rows), so a closed section still tells you something was changed.
export default class extends Controller {
  static targets = ["badge"]

  connect() {
    this.initial = this.snapshot()
    // A required field left empty inside a closed section: open it so the browser can point at the field.
    this.openOnInvalid = () => { this.element.open = true }
    this.element.addEventListener("invalid", this.openOnInvalid, true)
    this.observer = new MutationObserver(() => this.check())
    this.observer.observe(this.element, { childList: true, subtree: true })
  }

  disconnect() {
    this.observer?.disconnect()
    this.element.removeEventListener("invalid", this.openOnInvalid, true)
  }

  check() {
    this.badgeTarget.hidden = this.snapshot() === this.initial
  }

  snapshot() {
    return [...this.element.querySelectorAll("input[name], select[name], textarea[name]")]
      .filter((el) => !el.closest("template") && !((el.type === "radio" || el.type === "checkbox") && !el.checked))
      .map((el) => `${el.name}=${el.value.toLowerCase()}`)
      .join("&")
  }
}
