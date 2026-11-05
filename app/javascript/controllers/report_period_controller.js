import { Controller } from "@hotwired/stimulus"

// Shows only the inputs that apply to the selected report period.
export default class extends Controller {
  static targets = ["period", "field", "unit"]

  connect() {
    this.update(false)
  }

  toggle() {
    this.update(true)
  }

  update(animate) {
    const period = this.periodTarget.value
    // Hide outgoing fields first, then reveal incoming ones, so the grid doesn't hold both at once.
    const leaving = []
    const entering = []
    this.fieldTargets.forEach((field) => {
      const show = field.dataset.periods.split(" ").includes(period)
      field.querySelectorAll("input").forEach((input) => (input.disabled = !show))
      if (show && (field.hidden || field.classList.contains("field-out"))) entering.push(field)
      if (!show && !field.hidden) leaving.push(field)
    })
    if (this.hasUnitTarget && (period === "days" || period === "weeks")) this.unitTarget.textContent = period

    if (!animate) {
      leaving.forEach((field) => (field.hidden = true))
      entering.forEach((field) => (field.hidden = false))
      return
    }

    const reveal = () => entering.forEach((field) => this.reveal(field))
    if (leaving.length) {
      Promise.all(leaving.map((field) => this.conceal(field))).then(reveal)
    } else {
      reveal()
    }
  }

  reveal(field) {
    field.classList.remove("field-out")
    field.hidden = false
    field.classList.remove("field-in")
    void field.offsetWidth // restart the animation
    field.classList.add("field-in")
    field.addEventListener("animationend", () => field.classList.remove("field-in"), { once: true })
  }

  conceal(field) {
    return new Promise((resolve) => {
      field.classList.remove("field-in")
      field.classList.add("field-out")
      field.addEventListener("animationend", () => {
        if (field.classList.contains("field-out")) {
          field.hidden = true
          field.classList.remove("field-out")
        }
        resolve()
      }, { once: true })
    })
  }
}
