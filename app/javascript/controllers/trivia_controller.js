import { Controller } from "@hotwired/stimulus"

const LETTERS = ["A", "B", "C", "D"]

// Multiple-choice daily trivia. Progress (current question + answers) is kept per day in
// localStorage, so the dashboard and lock screen continue the same round.
export default class extends Controller {
  static values = { questions: Array, day: String }
  static targets = ["category", "progress", "question", "choices", "feedback", "score", "next"]

  connect() {
    this.state = this.#load()
    this.render()
  }

  get key() { return `timelog:trivia:${this.dayValue}` }
  get current() { return this.questionsValue[this.state.index] }
  get answered() { return this.state.answers[this.state.index] }

  render() {
    const q = this.current
    if (!q) return

    this.categoryTarget.textContent = `· ${q.category}`
    this.progressTarget.textContent = `${this.state.index + 1} / ${this.questionsValue.length}`
    this.questionTarget.textContent = q.question

    this.choicesTarget.replaceChildren(...q.choices.map((choice, i) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "trivia-choice"
      button.dataset.action = "trivia#answer"
      button.dataset.triviaChoiceParam = i
      const letter = document.createElement("b")
      letter.textContent = LETTERS[i]
      const label = document.createElement("span")
      label.textContent = choice
      button.append(letter, label)
      return button
    }))

    const picked = this.answered
    if (picked !== undefined && picked !== null) this.#reveal(picked)
    else {
      this.feedbackTarget.hidden = true
      this.nextTarget.hidden = true
    }
    this.#renderScore()
  }

  answer({ params: { choice } }) {
    if (this.answered !== undefined && this.answered !== null) return
    this.state.answers[this.state.index] = choice
    this.#save()
    this.#reveal(choice, true)
    this.#renderScore()
  }

  next() {
    const total = this.questionsValue.length
    if (this.#answeredCount() === total && this.state.index === total - 1) {
      this.state = { index: 0, answers: [] } // play the round again
    } else {
      this.state.index = (this.state.index + 1) % total
    }
    this.#save()
    this.render()
  }

  #reveal(picked, animate = false) {
    const q = this.current
    const correct = picked === q.answer_index
    this.choicesTarget.querySelectorAll(".trivia-choice").forEach((button, i) => {
      button.disabled = true
      if (i === q.answer_index) button.classList.add("correct")
      else if (i === picked) button.classList.add("wrong")
    })

    this.feedbackTarget.hidden = false
    this.feedbackTarget.className = `trivia-feedback ${correct ? "is-correct" : "is-wrong"}`
    this.feedbackTarget.textContent = `${correct ? "Correct! " : `Not quite — it's ${q.choices[q.answer_index]}. `}${q.explanation || ""}`
    if (animate) this.feedbackTarget.animate([{ opacity: 0, transform: "translateY(4px)" }, { opacity: 1, transform: "none" }], { duration: 220, easing: "ease-out" })

    const total = this.questionsValue.length
    const finished = this.#answeredCount() === total && this.state.index === total - 1
    this.nextTarget.hidden = false
    this.nextTarget.textContent = finished ? "Play again ↺" : "Next question →"
  }

  #renderScore() {
    const total = this.questionsValue.length
    const done = this.#answeredCount()
    const right = this.state.answers.filter((a, i) => a !== null && a !== undefined && a === this.questionsValue[i]?.answer_index).length
    this.scoreTarget.textContent = done === 0 ? "Pick an answer" : done === total ? `Final score: ${right}/${total} 🎉` : `Score: ${right}/${done}`
  }

  #answeredCount() {
    return this.state.answers.filter((a) => a !== null && a !== undefined).length
  }

  #load() {
    try {
      const saved = JSON.parse(localStorage.getItem(this.key))
      if (saved && Number.isInteger(saved.index) && saved.index < this.questionsValue.length && Array.isArray(saved.answers)) return saved
    } catch {}
    return { index: 0, answers: [] }
  }

  #save() {
    try {
      localStorage.setItem(this.key, JSON.stringify(this.state))
      // Drop earlier days' rounds
      Object.keys(localStorage).filter((k) => k.startsWith("timelog:trivia:") && k !== this.key).forEach((k) => localStorage.removeItem(k))
    } catch {}
  }
}
