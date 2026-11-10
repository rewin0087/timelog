import { Controller } from "@hotwired/stimulus"

// Grows a textarea to fit its text (fallback for browsers without CSS field-sizing),
// and submits its form on Cmd/Ctrl+Enter so plain Enter can add a new line.
export default class extends Controller {
  static targets = ["field"]

  connect() { this.resize() }

  resize() {
    if (CSS.supports("field-sizing", "content")) return
    const field = this.fieldTarget
    field.style.height = "auto"
    field.style.height = `${field.scrollHeight}px`
  }

  submitOnModEnter(event) {
    if (event.key !== "Enter" || !(event.metaKey || event.ctrlKey)) return
    event.preventDefault()
    this.element.requestSubmit()
  }
}
