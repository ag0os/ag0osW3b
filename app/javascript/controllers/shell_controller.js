import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// The shell on the home page. The server interprets every line (see
// app/services/shell.rb and SHELL.md); this adds what only a browser can do:
//
//   - plays the opening as if typed, once per session, skipped by any key
//   - command history on the arrow keys, completion on Tab, Ctrl+L to clear
//   - the commands that change state living in the browser (theme, light,
//     dark, clear, open), answered here without a round trip
//
// With JavaScript off none of this exists and the form still works: the
// server renders the page with the exchange appended.
export default class extends Controller {
  static targets = ["output", "input", "form", "opening", "template"]
  static values = { commands: Array, pages: Object, presets: Array, strings: Object }

  connect() {
    this.history = []
    this.cursor = 0
    this.local = {
      theme: this.theme, light: this.light, dark: this.dark, mode: this.mode,
      clear: this.clear, open: this.open, cd: this.open, go: this.open
    }
    this.playOpening()
  }

  disconnect() {
    this.stopOpening()
  }

  // ---- The opening ---------------------------------------------------------
  // The transcript is already in the DOM. Playing it means hiding it and
  // revealing one exchange at a time, typing the command before showing what
  // it printed. Skipping restores everything at once.

  playOpening() {
    const exchanges = this.openingTargets
    if (exchanges.length === 0 || this.played || this.reducedMotion) {
      this.finishOpening()
      return
    }

    this.playing = true
    exchanges.forEach((exchange) => { exchange.hidden = true })
    this.typeExchange(exchanges, 0)
  }

  async typeExchange(exchanges, index) {
    if (!this.playing) return
    if (index >= exchanges.length) {
      this.finishOpening()
      return
    }

    const exchange = exchanges[index]
    const command = exchange.querySelector(".shell__cmd")
    const output = exchange.querySelector(".shell__out")
    const text = command.textContent
    command.dataset.full = text
    command.textContent = ""
    output.hidden = true
    exchange.hidden = false

    for (const character of text) {
      if (!this.playing) return
      command.textContent += character
      await this.wait(30 + Math.random() * 45)
    }

    await this.wait(200)
    if (!this.playing) return
    output.hidden = false
    await this.wait(450)
    this.typeExchange(exchanges, index + 1)
  }

  finishOpening() {
    this.stopOpening()
    this.openingTargets.forEach((exchange) => {
      const command = exchange.querySelector(".shell__cmd")
      if (command.dataset.full !== undefined) command.textContent = command.dataset.full
      exchange.querySelector(".shell__out").hidden = false
      exchange.hidden = false
    })
    this.remember("played")

    // Only claim focus when nobody has it and there is a keyboard to type on.
    // A phone would get its keyboard popped, and a screen reader would be
    // yanked away from the top of the page.
    if (document.activeElement === document.body && window.matchMedia("(pointer: fine)").matches) {
      this.inputTarget.focus({ preventScroll: true })
    }
  }

  stopOpening() {
    this.playing = false
    clearTimeout(this.timer)
  }

  wait(ms) {
    return new Promise((resolve) => { this.timer = setTimeout(resolve, ms) })
  }

  get played() {
    try {
      return sessionStorage.getItem("shell:played") === "1"
    } catch (e) {
      return false
    }
  }

  remember() {
    try {
      sessionStorage.setItem("shell:played", "1")
    } catch (e) {
      // Private browsing: the opening simply plays again next time.
    }
  }

  get reducedMotion() {
    return window.matchMedia("(prefers-reduced-motion: reduce)").matches
  }

  // ---- Input ---------------------------------------------------------------

  submit(event) {
    const line = this.inputTarget.value.trim()
    if (!line) {
      event.preventDefault()
      return
    }

    this.history.push(line)
    this.cursor = this.history.length

    // A handler returns false to hand the line to the server after all, the
    // way `open` does for a page it does not know. Anything else is answered
    // here and Turbo never sees the submit.
    const [name, ...rest] = line.split(/\s+/)
    const handler = this.local[name.toLowerCase()]
    if (!handler || handler.call(this, rest.join(" "), line) === false) return

    event.preventDefault()
    this.inputTarget.value = ""
    this.settle()
  }

  // turbo:submit-start: Turbo has read the form, so the field can empty now.
  submitted() {
    this.inputTarget.value = ""
  }

  // turbo:submit-end: the answer has been appended.
  settled() {
    this.settle()
  }

  settle() {
    this.inputTarget.focus({ preventScroll: true })
    this.inputTarget.scrollIntoView({ block: "nearest" })
  }

  keydown(event) {
    if (this.playing) this.finishOpening()

    switch (event.key) {
      case "ArrowUp":
        event.preventDefault()
        this.recall(-1)
        break
      case "ArrowDown":
        event.preventDefault()
        this.recall(1)
        break
      case "Tab":
        if (this.complete()) event.preventDefault()
        break
      case "Escape":
        this.inputTarget.value = ""
        break
      case "l":
        if (event.ctrlKey) {
          event.preventDefault()
          this.clear("", "clear")
        }
        break
    }
  }

  recall(step) {
    if (this.history.length === 0) return
    this.cursor = Math.min(Math.max(this.cursor + step, 0), this.history.length)
    this.inputTarget.value = this.history[this.cursor] ?? ""
    const end = this.inputTarget.value.length
    this.inputTarget.setSelectionRange(end, end)
  }

  // Completes the command word. One match fills it in; several fill in what
  // they share and print the rest, the way a shell does on a second Tab.
  complete() {
    const value = this.inputTarget.value
    if (value === "" || /\s/.test(value)) return false

    const matches = this.commandsValue.filter((command) => command.startsWith(value.toLowerCase()))
    if (matches.length === 0) return true
    if (matches.length === 1) {
      this.inputTarget.value = `${matches[0]} `
      return true
    }

    const prefix = matches.reduce((shared, command) => {
      let i = 0
      while (i < shared.length && shared[i] === command[i]) i++
      return shared.slice(0, i)
    })
    if (prefix.length > value.length) {
      this.inputTarget.value = prefix
    } else {
      this.print(value, matches.join("  "))
    }
    return true
  }

  focus(event) {
    if (event.target.closest("a, button, input, kbd")) return
    if (window.getSelection().toString()) return
    this.inputTarget.focus()
  }

  // ---- Commands answered here ---------------------------------------------

  theme(argument, line) {
    const name = argument.trim().toLowerCase()
    if (!name) return this.print(line, this.stringsValue.theme_usage)
    if (!this.presetsValue.includes(name)) {
      return this.print(line, this.format("theme_unknown", { name, names: this.stringsValue.presets }))
    }

    this.themeController?.applyPreset(name)
    this.print(line, this.format("theme_switched", { name }))
  }

  light(_argument, line) {
    this.setMode("light", line)
  }

  dark(_argument, line) {
    this.setMode("dark", line)
  }

  mode(argument, line) {
    const name = argument.trim().toLowerCase()
    if (name !== "light" && name !== "dark") return this.print(line, "usage: light | dark")
    this.setMode(name, line)
  }

  setMode(name, line) {
    this.themeController?.setMode(name)
    this.print(line, this.format("mode_switched", { name }))
  }

  clear() {
    this.stopOpening()
    this.outputTarget.querySelectorAll(".shell__exchange").forEach((exchange) => exchange.remove())
    this.remember()
  }

  open(argument, line) {
    const name = argument.trim().toLowerCase().replace(/^\/|\/$/g, "") || ""
    const path = this.pagesValue[name === "posts" ? "writing" : name]
    if (!path) return false // the server prints its usage or not-found line
    Turbo.visit(path)
  }

  // ---- Output --------------------------------------------------------------

  print(line, text) {
    const exchange = this.templateTarget.content.firstElementChild.cloneNode(true)
    exchange.querySelector(".shell__cmd").textContent = line
    const message = exchange.querySelector(".shell__out p")
    if (text) {
      message.textContent = text
    } else {
      message.remove()
    }
    this.outputTarget.append(exchange)
  }

  format(key, values) {
    return (this.stringsValue[key] ?? "").replace(/%\{(\w+)\}/g, (_, name) => values[name] ?? "")
  }

  get themeController() {
    const element = document.querySelector("[data-controller~='theme']")
    return element && this.application.getControllerForElementAndIdentifier(element, "theme")
  }
}
