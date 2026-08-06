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
    this.render({ mode: next })
    this.store("mode", next)
    this.swap(() => { document.documentElement.dataset.mode = next })
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
    this.render({ preset })
    this.store("theme", preset)
    this.swap(() => { document.documentElement.dataset.theme = preset })
  }

  // Applies a theme change inside a view transition, which crossfades two
  // fully rendered frames.
  //
  // Only the repaint goes in here. startViewTransition defers its callback by
  // a frame, so putting render() inside it meant aria-pressed and aria-checked
  // still reported the old value immediately after the control was activated.
  // What a control announces about itself is not something to animate.
  //
  // The page used to get there by transitioning body's `color` and
  // `background-color`, which every paragraph inherits. On a light/dark flip
  // the text and the ground move toward each other and meet in the middle, so
  // for the length of the transition the page was close to unreadable.
  //
  // Falling back to an instant swap is not a degraded path: the switch is
  // legible either way, the crossfade is only character.
  swap(mutate) {
    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches

    if (reduced || !document.startViewTransition) {
      mutate()
      return
    }

    document.startViewTransition(mutate)
  }

  get preset() {
    return document.documentElement.dataset.theme
  }

  get mode() {
    const explicit = document.documentElement.dataset.mode
    if (explicit === "light" || explicit === "dark") return explicit
    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light"
  }

  // Both values are passed in rather than read back from <html>, because the
  // attribute that would answer for them has not been written yet: the repaint
  // is inside a view transition and this runs before it. They default to the
  // document for connect() and for the OS-preference listener.
  render({ preset = this.preset, mode = this.mode } = {}) {
    this.swatchTargets.forEach((swatch) => {
      const selected = swatch.dataset.preset === preset
      swatch.setAttribute("aria-checked", String(selected))
      // Roving tabindex: one stop for the whole group, not one per swatch.
      swatch.tabIndex = selected ? 0 : -1
    })

    if (!this.swatchTargets.some((s) => s.tabIndex === 0) && this.swatchTargets[0]) {
      this.swatchTargets[0].tabIndex = 0
    }

    const dark = mode === "dark"
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
