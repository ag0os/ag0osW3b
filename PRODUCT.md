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

## Contract: the Markdown renderer

`MarkdownRenderer` and its three helpers (`markdown`, `marked`, `unmarked`) turn what an author writes in the admin into what a visitor reads. Every obligation below has a test of the same number in `test/contract/markdown_renderer_contract_test.rb`. MR-17 to MR-20 are the change request "a mark may span inline formatting", and MR-21 makes any input render. Decisions and their derivations are in `DECISIONS.md`.

**What it renders**

- **MR-1** It renders GitHub-flavoured Markdown: emphasis, strong, strikethrough, tables, bare-URL and `www.` autolinks, task lists and footnotes. *Because* authors write posts and sections the way they write a README, and a construct that renders as literal punctuation is lost content.
- **MR-2** It sets typographic punctuation: curly quotes, `--` as an en dash, `...` as an ellipsis. *Because* the default preset is a printed proof, and straight quotes are a typewriter's.
- **MR-3** A single newline inside a paragraph is not a line break. *Because* a source wrapped at a fixed width must read as one paragraph.

**Safety.** The output goes into the page without escaping, and the shell plan will send visitor-derived text through it. So the only markup that comes out is the markup Markdown itself makes.

- **MR-4** Raw HTML in the source never reaches the output: no element, no attribute, no event handler. Inline tags are dropped and the words between them stay; a raw HTML block (a tag that starts a line, such as `<div>` or `<script>`) is dropped whole, words included.
- **MR-5** A link or image whose URL uses `javascript:`, `vbscript:` or `file:` loses its URL and keeps its text, and so does one using `data:`, unless its media type starts with `image/png`, `image/gif`, `image/jpeg` or `image/webp`. That is Commonmarker's safe-URL rule, and it is a prefix: `data:image/pngx` is kept too. Every match ignores case. Ordinary URLs (`https:`, `mailto:`, relative paths, fragments) are kept as written. *Because* those schemes can run script or read the visitor's machine. A kept `data:` URL can do neither, whatever follows the prefix. Its media type is an image type, which a browser decodes as an image or not at all and never runs as a document or script. The `data:` types that can carry script, `image/svg+xml` and `text/html`, don't match the prefix and stay emptied.
- **MR-6** The output is trusted markup, which a view inserts as it is.

**Tables**

- **MR-7** Every table sits in its own scroll region (class `table-scroll`), which is keyboard-focusable, has the role of a region and has an accessible name. *Because* one unbreakable token in a cell gives the whole page a horizontal scrollbar on a phone, and a region that scrolls must be reachable from the keyboard (WCAG 2.1.1). The class name is shared with the stylesheet.

**Code**

- **MR-8** A code block (fenced or indented) is a `pre.highlight` with a `code` inside, carrying `language-<name>` when the author named one. A block whose author named no language has no class on its `code`. The `pre` carries no `lang` attribute: in HTML `lang` names the human language of an element's content, so `lang="ruby"` would tell assistive technology the code is written in a language called Ruby. Tokens are spans with the short Pygments-style classes (`k`, `c1`, `s2`...) and no inline style anywhere. A block with no language or an unknown one is plain text in the same frame. *Because* highlighting is themed by plain CSS: seven rules serve all eight surfaces, and an inline colour would be right on one of them.
- **MR-9** Code shows exactly what the author typed, escaped. *Because* code is quoted, not interpreted.

**The mark.** `==phrase==` is the site's emphasis primitive (see DESIGN.md, "The mark and the note").

- **MR-10** `==phrase==` becomes a `<mark>` wherever prose appears: paragraphs, headings, quotes, list items, table cells, inside emphasis and inside links. A paragraph may hold several.
- **MR-11** A mark is never applied inside code, inline or block. *Because* `==` there is code (an operator, a test), not emphasis.
- **MR-12** An opening `==` must be followed by a character that is neither ASCII whitespace (a space, tab or line break) nor `=`, and a closing `==` preceded by one; equals signs that fail this stay as typed. Other Unicode spaces, such as a non-breaking space, count as content here, so `==`, a non-breaking space and `==` form a mark around that space. *Because* a line of `====` and an operator written in prose (`x == y`) are not marks.
- **MR-13** Marking never turns text into markup: what is inside a mark is as escaped as it was outside. Marking removes the four equals signs and nothing else: every other character before, inside and after a mark stays where it was, once.
- **MR-14** A mark never crosses a block boundary (paragraph, list item, quote, cell). That holds inside a tight list item too, where the item's text has no paragraph around it and sits beside a block (a code block, a quote, a nested list) in the same item.

**Plain strings** (the tagline, `whoami`, a page lead: single lines that are not Markdown)

- **MR-15** `mark` escapes everything and the only markup it outputs is the `<mark>` it adds, by the same delimiter rule as MR-12. Every pair in the string is marked, not only the first. It does not interpret Markdown. The result is trusted markup; `nil` gives an empty string. A newline is ordinary text here, so a mark may span lines; MR-14 is about Markdown blocks.
- **MR-16** `unmark` returns the same string with the delimiters removed and the words kept, for places that take text rather than markup: `<title>`, meta descriptions, the feed. Every mark in the string loses its delimiters, not only the first. Equals signs that are not a mark stay. The result is plain, untrusted text, which its caller escapes. `nil` gives an empty string. *Because* otherwise the tagline ships its own equals signs to every link preview.

**A mark may span inline formatting** (change request)

- **MR-17** A mark may contain any inline content: emphasis, strong, strikethrough, links and autolinks, inline code, images, footnote references and line breaks. That content keeps its formatting inside the mark, links keep their URL, code stays literal, and MR-13 still holds. A mark may itself sit inside formatting. *Because* `==a *b* c==` is how an author marks a phrase with a word stressed in it, and today it shows its equals signs.
- **MR-18** Equals signs inside code never open or close a mark. A mark with one end inside a code span and the other outside does not form.
- **MR-19** Both ends of a mark sit in the same element. A pair split by an element boundary (a link, emphasis) does not form: both stay as typed and the element is untouched. A stray `==` inside an element does not stop a mark around that element.
- **MR-20** An unpartnered `==` stays as typed and the formatting around it is untouched. Delimiters pair one element at a time, by the `mark` rule (MR-12: first opener to the nearest closer). Within an element, each child element and each piece of omitted raw HTML counts as one non-space character, whatever it contains, so the two equals signs of a delimiter never join across omitted HTML; delimiters outside a child never pair with delimiters inside it. Delimiters inside a child pair among themselves, unless a mark has formed around that child: then they stay as typed, because a mark never contains another mark.

**Any input renders** (settled 2026-10-08)

- **MR-21** `nil`, an empty string and a blank string (only whitespace, Unicode spaces such as U+00A0 included) render nothing. A string in any encoding renders rather than raising: it is read as the text it encodes; a binary string, or one in an encoding that has no converter to UTF-8, is read as UTF-8 bytes; and a byte sequence that is not valid text becomes U+FFFD (the replacement character). That holds in the string's own encoding too: a byte sequence invalid in it, or a byte it leaves undefined (0x81 in Windows-1252), also becomes U+FFFD. The caller's string is never changed, and a frozen string is accepted. *Because* the renderer sits in page templates, so a raise is a broken page. A section's body may be missing: the field is optional.
