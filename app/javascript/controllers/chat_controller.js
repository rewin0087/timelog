import { Controller } from "@hotwired/stimulus"

// The assistant chat: shows your message and a typing indicator straight away while the reply is worked out
// (the server's turbo stream then replaces #chat-pending with the saved messages), sends on Enter
// (Shift+Enter adds a line), sends a suggestion when its chip is clicked, and keeps the thread scrolled to the end.
export default class extends Controller {
  static targets = ["thread", "form", "input", "send"]

  connect() {
    this.observer = new MutationObserver(() => this.scrollToEnd())
    this.observer.observe(this.threadTarget, { childList: true, subtree: true })
    this.scrollToEnd()
    this.resize()
  }

  disconnect() {
    this.observer?.disconnect()
  }

  keydown(event) {
    if (event.key !== "Enter" || event.shiftKey || event.isComposing) return
    event.preventDefault()
    this.submit()
  }

  suggest({ params: { text } }) {
    if (!this.hasInputTarget || this.busy) return
    this.inputTarget.value = text
    this.submit()
  }

  submit() {
    if (this.busy || !this.inputTarget.value.trim()) return
    this.formTarget.requestSubmit()
  }

  sending() {
    this.busy = true
    this.pendingText = this.inputTarget.value
    this.threadTarget.querySelector(".chat-welcome")?.remove()
    this.threadTarget.append(this.pendingElement(this.pendingText.trim()))
    this.inputTarget.value = ""
    this.resize()
    this.sendTarget.disabled = true
    this.element.querySelector("#chat-suggestions")?.replaceChildren()
  }

  sent(event) {
    this.busy = false
    this.sendTarget.disabled = false
    if (!event.detail.success) {
      document.getElementById("chat-pending")?.remove()
      this.inputTarget.value = this.pendingText || ""
    }
    this.inputTarget.focus()
  }

  resize() {
    if (!this.hasInputTarget || CSS.supports("field-sizing", "content")) return
    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = `${this.inputTarget.scrollHeight}px`
  }

  scrollToEnd() {
    this.threadTarget.scrollTop = this.threadTarget.scrollHeight
  }

  pendingElement(text) {
    const wrapper = document.createElement("div")
    wrapper.id = "chat-pending"

    const mine = document.createElement("div")
    mine.className = "chat-msg chat-msg-user"
    const bubble = document.createElement("div")
    bubble.className = "chat-bubble"
    bubble.textContent = text
    mine.append(bubble)

    const typing = document.createElement("div")
    typing.className = "chat-msg chat-msg-assistant"
    typing.innerHTML = '<span class="chat-avatar" aria-hidden="true">✦</span><div class="chat-bubble chat-typing" aria-label="Assistant is typing"><i></i><i></i><i></i></div>'

    wrapper.append(mine, typing)
    return wrapper
  }
}
