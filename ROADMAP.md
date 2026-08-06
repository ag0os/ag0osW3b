# Roadmap

Parked ideas. Nothing here is committed work or a defect: the site ships
correctly without any of it. Each entry exists because a decision was reached
and deliberately deferred, and the reasoning is worth more than the conclusion.

Entries record **why the question came up**, **what the options were**, and
**what it would cost**, so picking one up later does not mean re-deriving the
argument. When one ships, delete its entry rather than marking it done. Git
remembers.

---

## Open

### Link previews have no image

*Raised 2026-08-05, during the design audit.*

`og:title`, `og:description`, `og:url`, `og:type`, `og:site_name` and
`twitter:card` all ship. `og:image` does not, so a link pasted into Slack,
LinkedIn, iMessage or Discord renders as a text-only card. `twitter:card` is set
to `summary` rather than `summary_large_image` for the same reason: the large
variant is pointless with no image to put in it.

This matters more than it looks. PRODUCT.md counts "an engineer subscribes or
returns" as success, and writing mostly travels by being pasted into a channel.
The card is the version of a post most people see first.

**Why it is parked:** it needs a decision about what the picture is, and this
site has four themes, so "which one does the card show" is a real question
rather than a detail.

**Options:**

| Approach | Cost | Notes |
|---|---|---|
| One static card | Low | A single 1200x630 PNG in the repo, same for every page. |
| One card per preset | Low | Four PNGs, chosen by `SiteSetting.theme_preset`. Shows the theme system off. |
| Generated per post | High | Best result, but needs an image library in Ruby. **Push back on this.** A dependency like that undercuts the no-build-step argument the whole repo is making. See AGENTS.md. |

**Leaning:** the switcher itself as the subject. The four two-tone chips, or one
page shown in four palettes. It is the only image that says what the site is
actually arguing, and it needs no photography.

Whatever ships, `og:image` needs an absolute URL, and `twitter:card` should move
to `summary_large_image` at the same time.

### The site contains no imagery at all

*Raised 2026-08-05, during the design audit.*

Zero images anywhere on the public site. The only two `background-image` rules
are the CSS-generated paper grain and spec's drawing grid. No photographs, no
screenshots, no diagrams, no illustrations.

The brand-register guidance treats text-only pages, where typography carries the
entire visual weight, as a failure mode. It also qualifies that imagery is
*required* only when the brief implies it (restaurants, hotels, fashion, travel,
photography). A personal engineering portfolio is not clearly on that list, so
this is a judgment call and not a rule violation.

**The counter-argument is real and it is in PRODUCT.md:** the switcher is the
visual artifact. "Craft is asserted by being demonstrated rather than
described." Under that reading the imagery is the design system, and a visitor
sees it by operating it. That argument holds.

**The sharper version of the concern** is not about decoration. PRODUCT.md's
first principle is:

> **Proof over claims.** Every screen leads with what was built, at what scale,
> with what result. When there is a choice between describing competence and
> demonstrating it, demonstrate it.

The Work page is seven bullets, and every one of them *describes*: "agent-first
AI orchestration framework built on Pi", "secure payment workflows for hundreds
of organizations", "45% frontend bundle reduction". A scanner reads adjectives
and numbers and has to take them on trust. One screenshot of Cosmonauts running,
or one diagram of how plan execution flows through agents, would *be* the proof
rather than a sentence asserting it exists.

So the gap is not "the page is plain". It is "the page tells where it could
show", on the one page whose whole job is showing.

**Options, ordered by how well they fit the repo's constraints:**

1. **A generated SVG diagram** of the agent-orchestration / plan-execution
   model. Hand-written SVG consuming the same design tokens, so it recolours
   across all four presets and both modes. No assets, no Node, no dependency. It
   would be the only element on the site that is simultaneously content *and* a
   demonstration of the theme system. Best fit by a distance.
2. **Product screenshots** of Cosmonauts or Claude Forge. Highest proof value,
   but they have to be supplied; they are not something the repo can generate.
3. **A photo.** Humanises the site. Belongs on About, not as a hero: PRODUCT.md
   lists the "headshot-and-tagline hero" among its anti-references.
4. **Nothing.** Accept that the switcher is the artifact. This is the current
   state and it is defensible.

**Leaning:** option 1, on its own, as a self-contained and reversible
experiment. It would also give spec's drawing grid a second thing to align to.

---

## Rejected

Nothing yet. Entries move here when a decision is made *against* them, with the
reason, so the same idea does not get re-proposed every six months.
