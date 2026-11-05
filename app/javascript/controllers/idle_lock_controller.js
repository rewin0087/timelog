import { Controller } from "@hotwired/stimulus"

const ACTIVITY_EVENTS = ["pointerdown", "pointermove", "keydown", "wheel", "touchstart", "scroll"]
const STORAGE_KEY = "timelog:last-activity"
const HEARTBEAT_EVERY = 60_000

// Locks the screen after the user's idle period, on Ctrl+Shift+L, and when another tab locks.
// Activity is shared across tabs (localStorage) and reported to the server (heartbeat), which
// enforces the same idle limit, so the lock holds even if this script never runs.
export default class extends Controller {
  static values = { minutes: Number, lockUrl: String, heartbeatUrl: String }

  connect() {
    this.lastBeat = 0
    this.lastActivity = Date.now()
    this.#store(this.lastActivity)

    this.onActivity = this.#activity.bind(this)
    this.onKey = this.#shortcut.bind(this)
    this.onVisible = () => document.visibilityState === "visible" && this.#check()
    ACTIVITY_EVENTS.forEach((e) => addEventListener(e, this.onActivity, { passive: true, capture: true }))
    addEventListener("keydown", this.onKey)
    document.addEventListener("visibilitychange", this.onVisible)

    this.channel = "BroadcastChannel" in window ? new BroadcastChannel("timelog-lock") : null
    if (this.channel) this.channel.onmessage = ({ data }) => data === "locked" && this.#showLockScreen()

    if (this.minutesValue > 0) this.timer = setInterval(() => this.#check(), 5000)
  }

  disconnect() {
    ACTIVITY_EVENTS.forEach((e) => removeEventListener(e, this.onActivity, { capture: true }))
    removeEventListener("keydown", this.onKey)
    document.removeEventListener("visibilitychange", this.onVisible)
    clearInterval(this.timer)
    this.channel?.close()
  }

  async lock() {
    if (this.locking) return
    this.locking = true
    clearInterval(this.timer)
    await this.#post(this.lockUrlValue)
    this.channel?.postMessage("locked")
    this.#showLockScreen()
  }

  #activity() {
    const now = Date.now()
    if (now - this.lastActivity < 1000) return
    this.lastActivity = now
    this.#store(now)
    if (now - this.lastBeat > HEARTBEAT_EVERY) {
      this.lastBeat = now
      this.#post(this.heartbeatUrlValue).then((r) => r?.status === 423 && this.#showLockScreen())
    }
  }

  #check() {
    if (this.minutesValue <= 0) return
    const last = Math.max(this.lastActivity, this.#stored())
    if (Date.now() - last >= this.minutesValue * 60_000) this.lock()
  }

  #shortcut(event) {
    if (event.ctrlKey && event.shiftKey && !event.altKey && event.key.toLowerCase() === "l") {
      event.preventDefault()
      this.lock()
    }
  }

  #showLockScreen() {
    window.Turbo ? window.Turbo.visit(this.lockUrlValue) : location.assign(this.lockUrlValue)
  }

  #post(url) {
    return fetch(url, {
      method: "POST",
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      credentials: "same-origin"
    }).catch(() => null)
  }

  #store(time) {
    try { localStorage.setItem(STORAGE_KEY, String(time)) } catch {}
  }

  #stored() {
    try { return Number(localStorage.getItem(STORAGE_KEY)) || 0 } catch { return 0 }
  }
}
