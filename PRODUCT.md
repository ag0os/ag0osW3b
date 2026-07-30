# Product

## Register

brand

## Users

Four audiences arrive at the same pages with different clocks running.

- **Founders and hiring managers** evaluating Agustin for senior or founding product-engineering roles. They need evidence of judgment and range quickly, then an obvious way to make contact.
- **Consulting clients** looking for AI-workflow and agent-orchestration help. Their real question is whether he has shipped this work or only written about it.
- **Peer engineers** arriving from GitHub, from Cosmonauts, or from a link to a post. They came for the ideas. Success is that they read, then come back.
- **Recruiters and scanners** skimming for credibility signals in under thirty seconds.

The design has to serve the thirty-second scan and the five-minute read at once, without turning into a resume for the first group or a wall of prose for the third.

## Product Purpose

Agustin Calabrese's personal site: a portfolio, a body of writing, and a standing argument that engineering judgment still matters in AI-native delivery. It exists to convert a stranger's attention into either a conversation (role, consulting) or a return visit (writing).

Content lives in the database and is edited at `/admin`, so the site can grow without a deploy.

The site also carries a second, quieter argument. Visitors can switch between several complete theme presets, each shipping light and dark. The switcher is not a settings toggle: it is the portfolio piece a visitor can operate. Craft is asserted by being demonstrated rather than described.

Success looks like: a founder emails; an engineer subscribes or returns; nobody bounces because the site looked like everyone else's.

## Brand Personality

**Considered, warm, unhurried.**

The voice of someone who has shipped payment systems for hundreds of organizations and spent thirteen years before that as a DJ, producer, and sound engineer. Technical without costume. Confident without volume. It states what was built, at what scale, and what was learned, then stops.

Emotionally the site should read as calm competence. Not velocity, not hype, not the future-of-everything. A visitor should come away thinking this person has good judgment, rather than this person is very excited.

The audio background is a real differentiator and is welcome as texture in voice and in the alternate presets. It should never become literal decoration (no waveform wallpaper, no fake VU meters on a portfolio).

## Anti-references

All four were named explicitly. Each is a match-and-refuse.

- **Generic SaaS landing.** Gradient blobs, "Trusted by" logo walls, three identical feature cards with rounded icons above each heading, purple-to-blue gradients.
- **AI-startup neon.** Neon on black, glowing orbs, particle fields, "the future of X" copy. Reads as hype in place of proof, which is the precise opposite of the argument this site is making.
- **Editorial magazine.** Display serif italic headlines, drop caps, broadsheet grids, small tracked uppercase labels stacked above every section heading. This lane is saturated across tech brand sites, and it is the trap the warm direction is most likely to drift into. Warmth here comes from palette, space, and humanist type, never from magazine grammar.
- **Recruiter CV template.** Skill bars, star ratings, percentage rings, timeline widgets, headshot-and-tagline hero. Looks like a resume builder rather than a person.

One more, from the repo's own rules: nothing that requires a Node toolchain. Tailwind, PostCSS, and JS bundlers are out of bounds. See `AGENTS.md`.

## Design Principles

1. **Proof over claims.** Every screen leads with what was built, at what scale, with what result. Numbers and repositories, not adjectives. When there is a choice between describing competence and demonstrating it, demonstrate it.

2. **The switcher is the portfolio.** Because visitors can operate the theme system, every preset is a shipped surface. A preset that is half-finished, or that fails contrast in one mode, actively damages the argument the site exists to make. There are no draft presets in production.

3. **Judgment moves earlier.** Taken from Agustin's own writing: AI does not remove engineering judgment, it relocates it into planning, architecture, constraints, and verification. The design system should embody that. Decisions get encoded as tokens and contracts up front, so later work is composition rather than improvisation.

4. **Legible in thirty seconds, rewarding in five minutes.** The scanner and the reader share every page. Structure carries the fast pass; depth rewards the slow one. Neither audience gets a degraded version.

5. **Constraint is part of the identity.** Vanilla Rails, plain CSS, no build step. The restraint is not a limitation being worked around, it is the same argument as the writing: strong fundamentals, deliberately chosen tools, nothing added without cause.

## Accessibility & Inclusion

**WCAG 2.2 AA is a hard contract, verified per preset and per mode.** With a multi-preset system this is a combinatorial commitment, not a single check: every preset times light and dark has to hold.

- Body text at 4.5:1 minimum. Large text, icons, borders, and interactive boundaries at 3:1 minimum.
- `prefers-reduced-motion: reduce` honored throughout. Motion is enhancement, never the only signal that something happened.
- No meaning carried by hue alone. Status, state, and emphasis always carry a second channel: shape, weight, icon, position, or text.
- Focus is always visible, and visible against every preset in both modes. Focus styling is a token, not a per-component afterthought.
- Theme and mode choices persist and apply before first paint, so no visitor gets a flash of the wrong surface.
- The site must remain usable and legible with JavaScript unavailable; theme switching is an enhancement layered on a working default.
