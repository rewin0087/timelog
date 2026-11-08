// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Direction for the page slide (see "Page navigation" in application.css):
//   forward/back follow the sidebar order, and the browser's back button always slides back;
//   a visit to the same page (form save, month paging) cross-fades; lock/unlock use the shutter.
if (document.startViewTransition) {
  const navLinks = () => [...document.querySelectorAll(".sidebar nav a")]
  const indexOf = (path) => navLinks().findIndex((a) => new URL(a.href).pathname === path)

  document.addEventListener("turbo:visit", ({ detail: { url, action } }) => {
    const path = new URL(url, location.href).pathname
    const from = navLinks().findIndex((a) => a.classList.contains("active"))
    const to = indexOf(path)

    let dir = "forward"
    if (path === "/lock") dir = "lock"
    else if (document.querySelector(".lock-screen")) dir = "unlock"
    else if (path === location.pathname && action !== "restore") dir = "same"
    else if (action === "restore" || (from >= 0 && to >= 0 && to < from)) dir = "back"
    document.documentElement.dataset.navDir = dir

    // Slide distance: from the page's left edge to the window's right edge (see --slide in application.css)
    const main = document.querySelector("main")
    if (main) document.documentElement.style.setProperty("--slide", `${Math.round(innerWidth - main.getBoundingClientRect().left)}px`)
  })
}
