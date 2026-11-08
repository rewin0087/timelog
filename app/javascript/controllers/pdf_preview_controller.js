import { Controller } from "@hotwired/stimulus"

// Opens a PDF in a modal before downloading. Triggers pass the PDF URL (and an optional title) as
// params; a trigger inside a form gets the form's current values added to the URL.
export default class extends Controller {
  static targets = ["dialog", "frame", "download", "title"]

  open(event) {
    const href = this.resolve(event)
    const inline = new URL(href, location.href)
    inline.searchParams.set("inline", "1")

    // Phone browsers can't render a PDF inside an iframe, so hand it to the browser's own viewer
    if (matchMedia("(max-width: 720px), (pointer: coarse) and (max-width: 1024px)").matches) {
      window.open(inline, "_blank", "noopener")
      return
    }

    this.titleTarget.textContent = event.params.title || "PDF preview"
    this.downloadTarget.href = href
    this.frameTarget.src = inline
    this.dialogTarget.showModal()
  }

  download(event) {
    event.preventDefault()
    location.href = this.resolve(event)
  }

  close() {
    this.dialogTarget.close()
  }

  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  closed() {
    this.frameTarget.src = "about:blank"
  }

  resolve(event) {
    const url = new URL(event.params.url, location.href)
    const form = event.currentTarget.closest("form")
    if (form) new FormData(form).forEach((value, key) => { if (key !== "authenticity_token") url.searchParams.set(key, value) })
    return url.pathname + url.search
  }
}
