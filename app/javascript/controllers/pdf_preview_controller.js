import { Controller } from "@hotwired/stimulus"

// Opens a PDF in a modal before downloading. Triggers pass the PDF URL (and an optional title) as
// params; a trigger inside a form gets the form's current values added to the URL. A draft that is only
// saved when downloaded (an invoice from the assistant) also passes a save URL: the modal's button then
// reads "Save & download" and POSTs there, and the server saves it and sends the PDF.
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
    this.saveUrl = event.params.saveUrl || null
    this.downloadTarget.href = href
    this.downloadTarget.textContent = this.saveUrl ? "Save & download" : "Download PDF"
    this.frameTarget.src = inline
    this.dialogTarget.showModal()
  }

  download(event) {
    event.preventDefault()
    location.href = this.resolve(event)
  }

  // The modal's download button: a plain link, unless the PDF is a draft that must be saved first.
  downloadOrSave(event) {
    if (!this.saveUrl) return
    event.preventDefault()
    const form = document.createElement("form")
    form.method = "post"
    form.action = this.saveUrl
    form.dataset.turbo = "false"
    const token = document.querySelector("meta[name=csrf-token]")?.content
    if (token) form.append(Object.assign(document.createElement("input"), { type: "hidden", name: "authenticity_token", value: token }))
    document.body.append(form)
    form.submit()
    form.remove()
    this.close()
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
