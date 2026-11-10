import { Controller } from "@hotwired/stimulus"

// PDF accent colour: preset swatches and a "Default" button fill the colour input; the active swatch is marked
// and the design card previews take the colour.
export default class extends Controller {
  static targets = ["input", "swatch"]
  static values = { default: String }

  connect() {
    this.mark()
  }

  pick(event) {
    this.set(event.currentTarget.dataset.color)
  }

  reset() {
    this.set(this.defaultValue)
  }

  set(color) {
    this.inputTarget.value = color
    this.inputTarget.dispatchEvent(new Event("input", { bubbles: true }))
    this.mark()
  }

  mark() {
    const current = this.inputTarget.value.toLowerCase()
    this.element.style.setProperty("--pdf-accent", current) // tints the design card previews
    this.swatchTargets.forEach((s) => {
      const on = s.dataset.color.toLowerCase() === current
      s.classList.toggle("active", on)
      s.setAttribute("aria-pressed", on)
    })
  }
}
