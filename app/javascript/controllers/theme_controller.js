import { Controller } from "@hotwired/stimulus"

// Swaps the skin instantly (with a circular reveal from the clicked swatch) and saves it to the session.
export default class extends Controller {
  choose(event) {
    const form = event.target.closest("form[data-theme-key]")
    if (!form) return
    event.preventDefault()

    const key = form.dataset.themeKey
    if (document.body.dataset.theme === key) return

    const button = form.querySelector("button")
    const rect = button.getBoundingClientRect()
    this.#reveal(rect.left + rect.width / 2, rect.top + rect.height / 2, () => this.#apply(key))

    fetch(form.action, {
      method: "POST",
      body: new FormData(form),
      headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name=csrf-token]")?.content },
      credentials: "same-origin"
    })
  }

  #apply(key) {
    document.body.dataset.theme = key
    this.element.querySelectorAll("form[data-theme-key]").forEach((f) => {
      const on = f.dataset.themeKey === key
      const b = f.querySelector("button")
      b.classList.toggle("active", on)
      b.setAttribute("aria-pressed", on)
    })
  }

  #reveal(x, y, update) {
    const reduce = matchMedia("(prefers-reduced-motion: reduce)").matches
    if (!document.startViewTransition || reduce) return update()

    const root = document.documentElement
    const radius = Math.hypot(Math.max(x, innerWidth - x), Math.max(y, innerHeight - y))
    root.style.setProperty("--reveal-x", `${x}px`)
    root.style.setProperty("--reveal-y", `${y}px`)
    root.style.setProperty("--reveal-r", `${radius}px`)
    root.dataset.vt = "theme"
    document.startViewTransition(update).finished.finally(() => delete root.dataset.vt)
  }
}
