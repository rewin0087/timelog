import { Controller } from "@hotwired/stimulus"

// Dashboard assistant panel: Enter sends (Shift+Enter adds a line), and while the first reply is worked out
// (a few seconds) it shows that it's thinking and stops double submits. The server then opens the chat.
export default class extends Controller {
  static targets = ["form", "status", "hint"]

  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    if (event.target.value.trim()) this.formTarget.requestSubmit()
  }

  busy() {
    this.element.classList.add("is-busy")
    this.statusTarget.hidden = false
    this.hintTarget.hidden = true
    this.element.querySelectorAll("textarea").forEach((el) => { el.readOnly = true })
    this.element.querySelectorAll("button, input[type=submit]").forEach((el) => { el.disabled = true })
  }
}
