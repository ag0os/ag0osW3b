import { Controller } from "@hotwired/stimulus"

// Drives the two theme axes on <html>:
//
//   data-theme   the design preset  (workshop | console | spec | terminal)
//   data-mode    light | dark
//
// Both persist to localStorage; the pre-paint script in the layout reads them
// back before first paint. data-mode is only ever written once the visitor has
// made a choice, so until then the OS preference decides via a media query.
//
// The list of valid presets comes from SiteSetting::PRESETS via a value, so
// Ruby stays the single source of truth.
export default class extends Controller {
  static targets = ["swatch", "modeButton", "modeLabel"]
  static values = { presets: Array }

  connect() {
    this.render()
    this.mediaQuery = window.matchMedia("(prefers-color-scheme: dark)")
    this.onSystemChange = () => this.render()
    this.mediaQuery.addEventListener("change", this.onSystemChange)
  }

  disconnect() {
    this.mediaQuery?.removeEventListener("change", this.onSystemChange)
  }

  choosePreset(event) {
    this.applyPreset(event.currentTarget.dataset.preset)
  }

  toggleMode() {
    const next = this.mode === "dark" ? "light" : "dark"
    document.documentElement.dataset.mode = next
    this.store("mode", next)
    this.render()
  }

  // Arrow keys move between swatches, as a radiogroup is expected to.
  navigate(event) {
    const keys = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }
    const step = keys[event.key]
    if (!step) return

    event.preventDefault()
    const swatches = this.swatchTargets
    const current = swatches.indexOf(event.currentTarget)
    const next = swatches[(current + step + swatches.length) % swatches.length]
    this.applyPreset(next.dataset.preset)
    next.focus()
  }

  applyPreset(preset) {
    if (!this.presetsValue.includes(preset)) return
    document.documentElement.dataset.theme = preset
    this.store("theme", preset)
    this.render()
  }

  get preset() {
    return document.documentElement.dataset.theme
  }

  get mode() {
    const explicit = document.documentElement.dataset.mode
    if (explicit === "light" || explicit === "dark") return explicit
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  render() {
    const active = this.preset

    this.swatchTargets.forEach((swatch) => {
      const selected = swatch.dataset.preset === active
      swatch.setAttribute("aria-checked", String(selected))
      // Roving tabindex: one stop for the whole group, not one per swatch.
      swatch.tabIndex = selected ? 0 : -1
    })

    if (!this.swatchTargets.some((s) => s.tabIndex === 0) && this.swatchTargets[0]) {
      this.swatchTargets[0].tabIndex = 0
    }

    const dark = this.mode === "dark"
    if (this.hasModeLabelTarget) this.modeLabelTarget.textContent = dark ? "☾" : "☀"
    if (this.hasModeButtonTarget) {
      this.modeButtonTarget.setAttribute("aria-pressed", String(dark))
    }
  }

  store(key, value) {
    try {
      localStorage.setItem(key, value)
    } catch (e) {
      // Private browsing or storage disabled: the choice just does not persist.
    }
  }
}
