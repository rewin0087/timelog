import { Controller } from "@hotwired/stimulus"

// Collapses the desktop sidebar to an icon rail. The choice is saved in a cookie so the server
// renders the same state on the next page load (see layouts/application.html.erb).
export default class extends Controller {
  toggle() {
    const collapsed = document.body.classList.toggle("sidebar-collapsed")
    document.cookie = `sidebar=${collapsed ? "collapsed" : "expanded"}; path=/; max-age=31536000; SameSite=Lax`
    const label = collapsed ? "Expand sidebar" : "Collapse sidebar"
    this.element.setAttribute("aria-expanded", !collapsed)
    this.element.setAttribute("aria-label", label)
    this.element.title = label
  }
}
