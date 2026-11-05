// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Slide direction for page transitions: follows the nav order, and browser back reverses it.
if (document.startViewTransition) {
  const navLinks = () => [...document.querySelectorAll(".sidebar nav a")]

  document.addEventListener("turbo:visit", ({ detail: { url, action } }) => {
    const path = new URL(url, location.href).pathname
    const from = navLinks().findIndex((a) => a.classList.contains("active"))
    const to = navLinks().findIndex((a) => new URL(a.href).pathname === path)
    const back = action === "restore" || (from >= 0 && to >= 0 && to < from)
    // Locking drops the lock screen down like a shutter; unlocking lifts it away
    const dir = path === "/lock" ? "lock" : document.querySelector(".lock-screen") ? "unlock" : back ? "back" : "forward"
    document.documentElement.dataset.navDir = dir
  })
}
