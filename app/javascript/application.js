// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Slide direction for page transitions: follows the nav order, and browser back reverses it.
if (document.startViewTransition) {
  const navLinks = () => [...document.querySelectorAll(".nav nav a")]

  document.addEventListener("turbo:visit", ({ detail: { url, action } }) => {
    const path = new URL(url, location.href).pathname
    const from = navLinks().findIndex((a) => a.classList.contains("active"))
    const to = navLinks().findIndex((a) => new URL(a.href).pathname === path)
    const back = action === "restore" || (from >= 0 && to >= 0 && to < from)
    document.documentElement.dataset.navDir = back ? "back" : "forward"
  })
}
