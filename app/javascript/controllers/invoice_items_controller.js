import { Controller } from "@hotwired/stimulus"

// Optional extra invoice lines: add/remove rows from a <template> and show each row's quantity x rate.
export default class extends Controller {
  static targets = ["list", "template", "row", "add", "empty"]
  static values = { max: Number, currency: String }

  connect() {
    this.refresh()
  }

  add() {
    if (this.rowTargets.length >= this.maxValue) return
    const html = this.templateTarget.innerHTML.replaceAll("__INDEX__", `${Date.now()}${this.rowTargets.length}`)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    this.rowTargets.at(-1).querySelector("input")?.focus()
    this.refresh()
  }

  remove(event) {
    event.currentTarget.closest("[data-invoice-items-target~='row']").remove()
    this.refresh()
  }

  refresh() {
    this.rowTargets.forEach((row) => {
      const qty = parseFloat(row.querySelector("[name$='[quantity]']").value) || 0
      const rate = parseFloat(row.querySelector("[name$='[rate]']").value) || 0
      row.querySelector(".item-total").textContent = `${this.currencyValue} ${(qty * rate).toLocaleString(undefined, { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`
    })
    if (this.hasAddTarget) this.addTarget.disabled = this.rowTargets.length >= this.maxValue
    if (this.hasEmptyTarget) this.emptyTarget.hidden = this.rowTargets.length > 0
  }
}
