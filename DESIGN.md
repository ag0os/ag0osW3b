---
name: ag0osW3b
description: A four-preset, eight-surface theme system for a personal site, built on plain CSS custom properties with no build step.
colors:
  # Canonical palette: the workshop preset, which is the site default.
  # The other three presets redefine these same semantic roles. See section 2.
  # Authored in OKLCH by doctrine; Stitch's linter warns on non-hex, which is
  # accepted here rather than splitting the source of truth.
  bg: "oklch(0.975 0.008 85)"
  bg-subtle: "oklch(0.945 0.012 85)"
  surface: "oklch(0.99 0.005 85)"
  border: "oklch(0.87 0.012 80)"
  border-strong: "oklch(0.62 0.02 80)"
  text: "oklch(0.27 0.018 60)"
  text-muted: "oklch(0.5 0.02 60)"
  text-faint: "oklch(0.61 0.018 60)"
  accent: "oklch(0.5 0.135 35)"
  accent-contrast: "oklch(0.985 0.006 85)"
  danger: "oklch(0.47 0.17 22)"
  success: "oklch(0.47 0.1 150)"
  # Preset identity accents, for the switcher chips.
  accent-workshop: "oklch(0.5 0.135 35)"
  accent-console: "oklch(0.66 0.19 48)"
  accent-spec: "oklch(0.5 0.21 27)"
  accent-terminal: "oklch(0.8 0.145 78)"
typography:
  display:
    fontFamily: "Seravek, Optima, Candara, Corbel, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(2.7rem, 1.9rem + 3.6vw, 4rem)"
    fontWeight: 600
    lineHeight: 1.15
    letterSpacing: "-0.015em"
  headline:
    fontFamily: "{typography.display.fontFamily}"
    fontSize: "clamp(2.15rem, 1.7rem + 2.1vw, 2.9rem)"
    fontWeight: 600
    lineHeight: 1.15
    letterSpacing: "-0.015em"
  title:
    fontFamily: "{typography.display.fontFamily}"
    fontSize: "clamp(1.7rem, 1.45rem + 1.1vw, 2.1rem)"
    fontWeight: 600
    lineHeight: 1.15
  body:
    fontFamily: "Iowan Old Style, Charter, Palatino Linotype, Georgia, ui-serif, serif"
    fontSize: "1.0625rem"
    fontWeight: 400
    lineHeight: 1.7
  label:
    fontFamily: "ui-monospace, SF Mono, Cascadia Mono, Menlo, Consolas, monospace"
    fontSize: "0.75rem"
    fontWeight: 400
    letterSpacing: "0.01em"
rounded:
  sm: "4px"
  md: "6px"
  lg: "10px"
spacing:
  "1": "0.25rem"
  "2": "0.5rem"
  "3": "0.75rem"
  "4": "1rem"
  "5": "1.5rem"
  "6": "2rem"
  "7": "3rem"
  "8": "4.5rem"
  "9": "7rem"
components:
  button-primary:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-contrast}"
    rounded: "{rounded.sm}"
    padding: "0.6rem 1.15rem"
  button-primary-hover:
    backgroundColor: "{colors.accent}"
    textColor: "{colors.accent-contrast}"
  button-secondary:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    padding: "0.6rem 1.15rem"
  tag:
    backgroundColor: "{colors.bg}"
    textColor: "{colors.text-muted}"
    rounded: "{rounded.lg}"
    padding: "0.1rem 0.55rem"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    padding: "0.55rem 0.7rem"
  swatch:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    size: "2rem"
---

# Design System: ag0osW3b

## 1. Overview

**Creative North Star: "The Patchbay"**

One signal, many routings. A patchbay does not change what runs through it; it changes where the signal goes and what colors it on the way out. This system works the same way. There is exactly one semantic contract, roughly forty named roles, and every component in the codebase is wired to that contract and to nothing else. Four presets sit behind the patchbay and answer those roles differently. Flip a jack and the whole site becomes a different design without a single component being rewritten.

The presets are not skins and they are not moods. Each is a complete design identity with its own palette, typeface stack, and shape language: **workshop** (ink on warm paper, the default), **console** (studio-hardware panel), **spec** (Swiss technical grid), and **terminal** (amber phosphor, mono). Each ships light and dark. Eight finished surfaces, no drafts. A visitor can operate the switcher from the header, which makes the system itself a portfolio piece rather than a settings screen.

What this explicitly rejects: the generic SaaS landing page, AI-startup neon, editorial-magazine affectation, and the recruiter CV template. It also rejects anything requiring a Node toolchain. This is plain CSS custom properties served by Propshaft, and the restraint is the same argument the writing makes.

**Key Characteristics:**
- Two orthogonal axes on `<html>`: `data-theme` for identity, `data-mode` for light and dark
- Presets vary color, type, shape, **rhythm, section grammar, ground and motion**. Never structure
- All color authored in OKLCH, chroma reduced toward the lightness extremes
- No `#000`, no `#fff`. Every neutral is tinted toward its preset hue
- WCAG AA is a failing test, not an intention
- Self-hosted open-licensed type, no third-party request at runtime

### The presentation layer

Palette and typeface alone produced four recolors of one page. What separates a
design from a color scheme is how it punctuates, how tightly it breathes, what
ground it sits on, and how it moves. Those are tokens too:

| Token | What it decides | Range across presets |
|---|---|---|
| `--density` | multiplier on the whole spacing scale | `0.84` spec to `1.18` workshop |
| `--rule-width` / `--rule-style` | how sections are separated | none, hairline, double seam, dashed |
| `--heading-marker` | what precedes a heading | nothing, `CH.01`, `01`, `$ ` |
| `--texture` | the page's ground, CSS-generated | paper grain, none |
| `--grid` | a structural grid over the content column | drawing grid, none |
| `--rail-align` | which edge rail content sits on | left, right |
| `--ease` / `--dur` / `--stagger` | how the preset moves | stepped snap to slow drift |
| `--ink-stroke` / `--lamp-*` / `--dimension-*` / `--endmark-*` | the preset's one delight | answered by exactly one preset each |

`--texture` and `--grid` are separate on purpose. A texture is a material the
whole page is printed on, so it is full-bleed on `<body>`. A grid is something
drawn against, so it tracks the content column: `--maxw` is exactly 8 columns of
`--grid-column` plus both gutters, and the first rule lands on the text edge.
Painted full-bleed it was anchored to the viewport while the content was
anchored to a centred container, so the two never aligned at any width.

**The One Structure Rule.** Presets vary rhythm and ornament. They never vary
markup. A section is the same element in all four; only its punctuation differs.
This is what keeps a component a single implementation while the designs stay
genuinely distinct.

### The rail

The page is two columns: a metadata rail and a text column. Everything that
annotates the text (section markers, post dates, tags, the hero eyebrow) sits in
the margin, and the text column holds nothing but text.

The rail exists because the reading measure is capped in `ch` and cannot grow.
A container wider than the measure is only honest if something fills the
difference; the alternative, shrinking the container to the measure, leaves a
centred column of text with symmetric voids, which is the shape brand work is
supposed to avoid. So the width has to be earned rather than removed.

The numbers are interlocked and all live in `:root`:

| | |
|---|---|
| content column | `960px` = 12 x `--grid-column` |
| rail + `--rail-gap` | `160px` = 2 columns, so text starts on a grid line |
| text column | `800px` = 10 columns |
| `--maxw` | `960px` + two `2.5rem` gutters = `65rem` |

**The Widest Preset Wins Rule.** The text column is sized by the widest-set
body font, not the narrowest. 68ch of spec's grotesque needs `732px` where
workshop's old-style serif needs `616px` for the same count, so a column fitted
to workshop clips spec below the 65ch floor. It is a legibility floor, so the
widest preset sets the column and narrower ones leave slack at the right.

**The Fold Rule.** Below `60rem` the rail costs more than it gives, because the
text column would drop under 65ch. It folds back into the flow and its contents
sit above what they annotate. `test/system/layout_test.rb` fails if the measure
leaves the 65-75ch band in any preset, at either width.

**The Earned Ornament Rule.** Every decorative element names the object it comes
from: spec's grid is a drawing grid, console's seam is a panel seam, terminal's
`$` is a prompt. Ornament that cannot name its referent is decoration, and it
does not ship.

### The delights

One per preset, and exactly one:

| Preset | Delight | Where | Referent |
|---|---|---|---|
| workshop | the ink stroke: a title's underline is drawn from the left and lifts off to the right | post lists | a pen laid on the page |
| console | the tally lamp: lit while its section is on screen, dim once it has passed | section markers | a live channel on a desk |
| spec | the dimension: `\|— 10 COL —\|` under the hero, countable against the grid | home hero | a drawing stating its overall width |
| terminal | the prompt returns | end of a post | a session going idle |

**The One Delight Rule.** Each is a token slot that is inert in `:root` and
answered by a single preset, the same way `--cursor-content` is: the mechanism
ships in all four, the performance belongs to one. A slot two presets answer is
site furniture rather than anyone's signature, and a preset collecting several
is where delight turns into the noise it is meant to be the opposite of.
`test/design/stylesheet_test.rb` fails the build on either.

Consequently none of them needs a component to know which preset it is in, and
the volume of each matches the volume of its preset: workshop's is a slow
underline, terminal's blinks.

## 2. Colors

Four palettes with four different jobs, sharing one set of role names. The strategy varies per preset on purpose: a calm identity and a restless one should not share palette mechanics.

### Primary

- **Oxide Red** (workshop, `oklch(0.5 0.135 35)`): the default accent. Restrained strategy, held under about 10% of any screen. Links, the primary button, the focus ring. Lifts to a warm rust in dark mode so it stays legible without turning neon.
- **Signal Orange** (console, `oklch(0.66 0.19 48)`): Committed strategy. The only preset where the accent carries real surface area, because a hardware panel earns one loud control. Note the split: the vivid orange is the *fill*, while links use a darker burnt orange, since high-chroma orange cannot clear 4.5:1 as text on a light panel.
- **Signal Red** (spec, `oklch(0.5 0.21 27)`): Restrained, near-monochrome. One red against near-white, used the way a spec sheet uses red: to mark the thing that matters, never to decorate.
- **Amber Phosphor** (terminal, `oklch(0.8 0.145 78)`): Committed, dark-first. Amber and not green, deliberately. Green on black is the AI-startup cliché this site exists to argue against; amber reads as a 1970s terminal manual and as the hardware lineage behind it.

### Neutral

- **Warm Paper / Walnut** (workshop, `oklch(0.975 0.008 85)` light, `oklch(0.21 0.014 60)` dark): warmth comes from here, not from typography. The dark mode is walnut rather than charcoal.
- **Panel Grey** (console, `oklch(0.895 0.006 95)` light): a mid-grey page ground, not a white one. The page is the equipment face.
- **Cool White / Slate** (spec, `oklch(0.98 0.003 250)` light): the only cool-neutral preset. Hairline rules read as drawn on it.
- **Warm Black / Fanfold** (terminal, `oklch(0.135 0.012 65)` dark, `oklch(0.955 0.01 90)` light): terminal's light mode is a line printer on fanfold paper, and it is finished work, not a fallback.

### Named Rules

**The Contract Rule.** Components read semantic role names and nothing else. A `[data-theme="..."]` selector in a component file is forbidden, and a hex or `rgb()` literal in any stylesheet is forbidden. If a component needs to differ per preset, the difference belongs in the token contract. This is enforced by `test/design/stylesheet_test.rb`.

**The Eight Surfaces Rule.** Nothing ships until it holds in four presets times two modes. `test/design/contrast_test.rb` parses the OKLCH values out of `themes.css`, converts to sRGB, and fails the build on any pair below AA. Adding a preset adds coverage automatically; the test discovers presets from the stylesheet rather than keeping its own list.

**The Paint Chip Rule.** Switcher swatches are mode-independent. A chip stands for a preset's identity, not for how that preset happens to render right now, so it does not shift under the visitor when they flip modes.

**The Second Channel Rule.** No meaning is ever carried by hue alone. The selected swatch has a border, a ring, and a check glyph. A flash notice and a flash alert differ by glyph before they differ by color. Status badges carry the word.

## 3. Typography

| Preset | Display | Body | Mono |
|---|---|---|---|
| workshop | Alegreya Sans | Alegreya | Sometype Mono |
| console | Archivo | Archivo | Azeret Mono |
| spec | Schibsted Grotesk | Schibsted Grotesk | Geist Mono |
| terminal | Martian Mono | Sometype Mono | Sometype Mono |

**Character:** workshop pairs a humanist sans heading with an old-style book serif, which inverts magazine grammar deliberately: sans over serif reads as a book, serif over sans reads as a magazine, and this site is not a magazine. Console is an industrial grotesque with a geometric mono for values, the way equipment is actually lettered. Spec is one contemporary grotesque at tight tracking with strong weight contrast. Terminal is mono throughout, wide and boxy for display, readable for text.

All open licensed (OFL), self-hosted via `bin/fetch-fonts`, latin subset only. No third-party request at runtime. Every `--font-*` token carries a full system-stack fallback, so a missing file degrades to a system face rather than breaking anything.

None of these appear on the reflex-reject list. That list exists because Inter, Space Grotesk, Fraunces and their neighbours are what training data reaches for first, and a personal site that lands on them is indistinguishable from every other one.

### Hierarchy

- **Display** (600 to 700, `clamp(2.7rem, 1.9rem + 3.6vw, 4rem)`, 1.15): the hero title only. Capped at 17ch so it breaks into a shape rather than a paragraph.
- **Headline** (600 to 700, `clamp(2.15rem, 1.7rem + 2.1vw, 2.9rem)`, 1.15): page titles and post titles.
- **Title** (600 to 700, `clamp(1.7rem, 1.45rem + 1.1vw, 2.1rem)`, 1.15): section headings, each sitting under a hairline rule.
- **Body** (400, `1.0625rem`, 1.6 to 1.7): prose. Measure is capped at **68ch**, expressed in `ch` rather than `rem` so it self-corrects per preset: workshop's serif and terminal's mono need different pixel widths for the same character count.
- **Label** (400 to 600, `0.75rem`, tracking varies): dates, tags, table headers, metadata.

### Named Rules

**The Borrowed Label Rule.** Small tracked uppercase labels are normally AI scaffolding. They exist in exactly one preset, console, where equipment labeling is the named system the whole identity is built on. The `--case-label` token resolves to `uppercase` there and `none` everywhere else. Do not copy the pattern into another preset.

**The Measure Rule.** Body text is capped in `ch`, never in `rem` or `px`. A fixed pixel measure is correct in one preset and wrong in three.

## 4. Elevation

Flat by default, and flatter as the presets get more technical. Depth is carried by tonal layering (`--bg` recedes to `--bg-subtle`, rises to `--surface`) and by hairline borders, not by shadow. Two of the four presets have no shadow vocabulary at all.

### Shadow Vocabulary

- **Workshop** (`0 1px 2px .../0.05, 0 8px 24px .../0.06`): a barely-there paper lift. Used on admin cards only.
- **Console** (`0 1px 0 0 ...`): a hard 1px edge with zero blur. A machined seam, not a glow.
- **Spec** (`none`): the grid carries structure. A shadow here would be a lie about the material.
- **Terminal** (`none`): nothing is raised, and nothing glows.

### Named Rules

**The No Glow Rule.** Terminal forbids `text-shadow`, bloom, gradients, scanline overlays, and particles. The restraint is the only thing separating it from the neon cliché it resembles. If terminal starts looking cool, it is broken.

**The Flat Default Rule.** A new component gets no shadow until someone can name the physical reason it is off the page. If the audit test is "would this look like a 2014 app", the answer is usually yes, and the fix is a border.

## 5. Components

### Buttons

- **Shape:** preset-driven radius, from soft (`6px`, workshop) to machined (`3px`, console) to square (`0`, spec and terminal).
- **Primary:** `--accent-fill` background with `--accent-contrast` text, padding `0.6rem 1.15rem`, display font at weight 650. The fill and text pair is contrast-tested as a unit.
- **Secondary:** `--surface` background with a `--border-strong` boundary, tested at 3:1 so the edge is real for everyone.
- **Hover / Focus:** background shifts toward `--text` by a computed `color-mix`. Focus is never restyled per component; it comes from the global `:focus-visible` rule.

### Chips

- **Style:** `--border` hairline, `--radius-lg` corners, mono label. Used for post tags.
- **State:** static. Tags are not filters here, and they should not pretend to be.

### Cards / Containers

Cards are deliberately rare. The public site has none: post lists are rule-separated rows, not a grid of boxes. The admin dashboard uses them for four unrelated counts, which is the one case where a card is the honest affordance.

- **Corner Style:** `--radius` (preset-driven).
- **Background:** `--surface` over `--bg`.
- **Shadow Strategy:** `--shadow`, which is `none` in two presets. See Elevation.
- **Border:** always a `--border` hairline, since the shadow cannot be relied on.
- **Internal Padding:** `--space-4`.

### Inputs / Fields

- **Style:** `--surface` fill, `--border-strong` stroke at 3:1, `--radius-sm` corners.
- **Focus:** the global 2px `--focus` outline at 2px offset. `color-scheme` is set per mode, so native controls, scrollbars, and autofill match the surface instead of reverting to light.
- **Error:** `--danger-bg` and `--danger-border`, both computed from `--danger` with `color-mix`, plus a leading glyph.

### Navigation

Text links at `--text-muted`, rising to `--text` on hover. The current page carries weight plus a 2px inset rule under the label plus `aria-current="page"`. Three signals, none of them hue. On narrow viewports the brand wraps to its own line and the nav sits below it.

### Theme Switcher (signature component)

The one component that is also the argument. Four swatch buttons in a `radiogroup`, each a diagonal two-tone chip showing that preset's characteristic surface and accent. Arrow keys move between them, roving `tabindex` keeps the group to a single tab stop, and the selection carries border, ring, and check glyph. It sits beside a light/dark toggle that is a separate control on a separate axis.

The whole thing is hidden until the pre-paint script adds a `js` class to `<html>`, because a control that cannot work is worse than a control that is not there.

## 6. Do's and Don'ts

### Do:
- **Do** consume semantic roles only: `--bg`, `--text`, `--accent`, `--radius`, `--font-body`. Every one of them resolves correctly in all eight surfaces.
- **Do** author color in OKLCH in `themes.css`, and reduce chroma as lightness approaches either extreme.
- **Do** derive tints with `color-mix(in oklab, ...)` against `--bg` or `--text` rather than hand-authoring a new hex.
- **Do** run `bin/rails test` after touching any token. The contrast test is the gate on the accessibility contract.
- **Do** express reading measure in `ch` and check new components in workshop and terminal, the two presets whose character widths differ most.
- **Do** give every state a second channel: glyph, weight, position, or text alongside the color.
- **Do** add a preset by copying a token block, filling all 14 pairs, and adding the name to `SiteSetting::PRESETS`. No component should need to change.

### Don't:
- **Don't** hardcode a hex, `rgb()`, or `hsl()` value in any stylesheet. It will be right in one surface and wrong in seven.
- **Don't** branch a component on `[data-theme="..."]`. Push the difference into the token contract instead.
- **Don't** vary spacing or layout per preset. The shared skeleton is what keeps a component a single implementation.
- **Don't** build the generic SaaS landing page: gradient blobs, "Trusted by" logo walls, three identical feature cards with rounded icons above each heading.
- **Don't** reach for AI-startup neon: neon on black, glowing orbs, particle fields, "the future of X" copy.
- **Don't** drift into editorial magazine: display serif italic headlines, drop caps, broadsheet grids, small tracked uppercase labels stacked above every section heading. Warmth comes from palette, space, and humanist type.
- **Don't** build the recruiter CV template: skill bars, star ratings, percentage rings, timeline widgets, headshot-and-tagline hero.
- **Don't** add Tailwind, PostCSS, `cssbundling`, `jsbundling`, or any Node toolchain. See `AGENTS.md`.
- **Don't** put `*/` inside comment prose. It closes the comment early, and CSS fails silently: every route still returns 200 while the entire token layer evaporates. `test/design/stylesheet_test.rb` catches it now, but do not write it in the first place.
