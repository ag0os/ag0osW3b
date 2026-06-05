import { Controller } from "@hotwired/stimulus"

// Toggles between light/dark by flipping data-theme on <html> and persisting
// the choice to localStorage. The pre-paint script in the layout reads it back.
export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.render(this.current)
  }

  toggle() {
    const next = this.current === "dark" ? "light" : "dark"
    document.documentElement.dataset.theme = next
    try { localStorage.setItem("theme", next) } catch (e) {}
    this.render(next)
  }

  get current() {
    return document.documentElement.dataset.theme === "dark" ? "dark" : "light"
  }

  render(theme) {
    if (this.hasLabelTarget) this.labelTarget.textContent = theme === "dark" ? "☾" : "☀"
  }
}
