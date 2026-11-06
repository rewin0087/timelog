import { Controller } from "@hotwired/stimulus"

// Lock screen: live clock, PIN dots, on-screen keypad, or a plain "type the code" field (remembered per browser).
// Also tells other tabs when the session unlocks.
const MODE_KEY = "timelog-lock-mode"

export default class extends Controller {
  static targets = ["input", "dots", "form", "time", "date", "modeToggle"]

  connect() {
    // Drop page snapshots so Back can't show what was on screen before the lock
    window.Turbo?.cache.clear()
    this.tick()
    this.clock = setInterval(() => this.tick(), 1000)
    this.sync()
    this.#applyMode(this.#storedMode() === "type")
    this.channel = "BroadcastChannel" in window ? new BroadcastChannel("timelog-lock") : null
    if (this.channel) this.channel.onmessage = ({ data }) => { if (data === "unlocked") window.Turbo?.visit("/") }
  }

  disconnect() {
    clearInterval(this.clock)
    this.channel?.close()
  }

  press({ params: { digit } }) {
    if (this.inputTarget.value.length >= 8) return
    this.inputTarget.value += digit
    this.sync()
    this.#bump()
  }

  erase() {
    this.inputTarget.value = this.inputTarget.value.slice(0, -1)
    this.sync()
  }

  toggleMode() {
    const typing = !this.formTarget.classList.contains("typing")
    try { localStorage.setItem(MODE_KEY, typing ? "type" : "pad") } catch {}
    this.#applyMode(typing)
    this.inputTarget.focus()
  }

  enter(event) {
    event.preventDefault()
    if (this.inputTarget.value) this.formTarget.requestSubmit()
  }

  sync() {
    const input = this.inputTarget
    input.value = input.value.replace(/\D/g, "").slice(0, 8)
    const n = input.value.length
    const slots = Math.max(4, n)
    this.dotsTarget.innerHTML = Array.from({ length: slots }, (_, i) => `<i class="${i < n ? "on" : ""}"></i>`).join("")
  }

  submitted({ detail: { success } }) {
    if (success) this.channel?.postMessage("unlocked")
  }

  tick() {
    const now = new Date()
    this.timeTarget.textContent = now.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
    this.dateTarget.textContent = now.toLocaleDateString([], { weekday: "long", day: "numeric", month: "long" })
  }

  #applyMode(typing) {
    this.formTarget.classList.toggle("typing", typing)
    this.inputTarget.placeholder = typing ? "Enter lock code" : ""
    this.modeToggleTarget.textContent = typing ? "Use keypad instead" : "Type code instead"
  }

  #storedMode() {
    try { return localStorage.getItem(MODE_KEY) } catch { return null }
  }

  #bump() {
    const dot = this.dotsTarget.querySelectorAll("i.on")[this.inputTarget.value.length - 1]
    dot?.animate([{ transform: "scale(.4)" }, { transform: "scale(1.35)" }, { transform: "scale(1)" }], { duration: 260, easing: "ease-out" })
  }
}
