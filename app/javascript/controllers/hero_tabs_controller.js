import { Controller } from "@hotwired/stimulus"

// Tabs on the dashboard's top card (Today's todo / Assistant) when both are shown.
// The last tab picked is remembered in this browser; arrow keys move between tabs.
export default class extends Controller {
  static targets = ["tab", "panel"]
  static storageKey = "dashboard-hero-tab"

  connect() {
    let saved = null
    try { saved = localStorage.getItem(this.constructor.storageKey) } catch {}
    this.show(this.tabTargets.some((t) => t.dataset.tab === saved) ? saved : "todo")
  }

  select(event) {
    this.show(event.currentTarget.dataset.tab, { focus: true })
    try { localStorage.setItem(this.constructor.storageKey, event.currentTarget.dataset.tab) } catch {}
  }

  keydown(event) {
    if (!["ArrowLeft", "ArrowRight"].includes(event.key)) return
    const index = this.tabTargets.indexOf(event.currentTarget)
    const next = this.tabTargets[(index + (event.key === "ArrowRight" ? 1 : -1) + this.tabTargets.length) % this.tabTargets.length]
    next.focus()
    next.click()
  }

  show(name, { focus = false } = {}) {
    this.tabTargets.forEach((tab) => {
      const on = tab.dataset.tab === name
      tab.setAttribute("aria-selected", on)
      tab.tabIndex = on ? 0 : -1
    })
    this.panelTargets.forEach((panel) => { panel.hidden = panel.dataset.tab !== name })
    if (focus) this.panelTargets.find((p) => !p.hidden)?.querySelector("textarea")?.focus()
  }
}
