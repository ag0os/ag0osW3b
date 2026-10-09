# Decisions

Why things are the way they are, with the derivation behind each value. Version control says what changed; a record here says why. Obligations are numbered as in `PRODUCT.md` ("Contract: the Markdown renderer").

## The Markdown renderer

### D-1. The mark is applied to the rendered Markdown, not to the source

**Decision.** Commonmarker renders first; `==phrase==` is found afterwards, in the text of the result.

**Derivation.** Whether `==` is emphasis depends on context the source does not show without parsing it: inside a code span, a fenced block or an indented block it is code (`a == b`, a test assertion). The Markdown parser already knows which text is code. Finding marks in the rendered text, with code excluded, inherits that knowledge instead of re-deriving it with a second, weaker parser. Rewriting the source to `<mark>` before parsing would also need raw HTML enabled (MR-4 forbids it) or a private syntax extension Commonmarker does not offer. Obligations: MR-11, MR-18.

### D-2. Marking never reparses text

**Decision.** Marking moves the existing nodes into the `<mark>` and creates new text nodes for the pieces of split text. The only markup it adds is the `<mark>` element.

**Derivation.** Reading text out of an HTML tree decodes it: `&lt;i&gt;` comes back as `<i>`. Putting it back as markup would turn an author's (or, once the shell answers from the site, a visitor's) escaped text into live HTML, which MR-4 exists to prevent. A text node is escaped when the tree is serialised, so text that stays a text node stays text, and a moved node keeps the attributes the sanitiser left it. `mark` has no tree, so it escapes the whole string before adding marks. Obligations: MR-13, MR-15, MR-17.

### D-3. Commonmarker's own highlighter is off; Rouge runs with classes

**Decision.** Commonmarker is called with `syntax_highlighter: nil`; code blocks are re-highlighted with Rouge's HTML formatter, which emits class names.

**Derivation.** Commonmarker's built-in highlighter (syntect) writes colours as inline `style` attributes from one fixed theme. The site ships four presets in two modes, eight surfaces, and every colour has to come from tokens (`DESIGN.md`, "Don't hardcode"). A class-based formatter lets the `.highlight` rules read `--hl-*` tokens, so seven rules serve eight surfaces, and keeps inline styles out of the output entirely. Rouge emits the short Pygments class names the stylesheet already targets. Obligation: MR-8.

### D-4. The delimiter needs a character other than ASCII whitespace or `=` on its inner side

**Decision.** `==` opens a mark only when followed by a character other than ASCII whitespace (a space, tab or line break) or `=`, and closes one only when preceded by one (the lookarounds in `MARK`).

**Derivation.** Two real inputs contain `==` and are not marks. A line of `====` is a setext heading rule, or a divider someone typed; without the rule it pairs with itself. An operator in prose (`x == y`, `a ==  == b`) has spaces around it. Requiring a non-space inside both ends excludes both and costs nothing a real mark needs, since nobody marks a phrase that starts or ends with a space. This is the same flanking idea CommonMark uses for `*`. A run of `=` of any length is a rule or a divider: with only a non-space rule, `=====` pairs its outer four signs around the fifth. The whitespace is ASCII only, so a non-breaking space or an em space counts as content. That is the shipped behaviour, pinned as it is (2026-10-09). The two cases the rule exists for are typed with ordinary spaces, and a non-breaking space next to `==` is something an author put there on purpose. MR-21 treats Unicode spaces as blank for a different question: whether there is anything to render at all. Obligation: MR-12.

### D-5. Tables get a focusable, labelled scroll region

**Decision.** Each table is wrapped in a `div.table-scroll` with `tabindex="0"`, `role="region"` and an `aria-label`.

**Derivation.** Cells wrap, so column count alone is safe on a phone. What bursts a column is one unbreakable token (an env var name, a long identifier), and then the whole page scrolls sideways. Scrolling the table inside its own box fixes that. A box that scrolls must be reachable from the keyboard, or a keyboard user cannot see the hidden columns (WCAG 2.1.1), so it takes a tab stop; a tab stop with the region role needs an accessible name. Obligation: MR-7.

### D-6. Raw HTML is omitted, and unsafe URLs are emptied

**Decision.** Commonmarker runs with `unsafe: false` and `tagfilter: true`.

**Derivation.** The helpers return trusted markup that views insert without escaping, so the renderer is the sanitiser. Omitting raw HTML entirely is simpler and stricter than an allow-list, and the site has no content that needs raw HTML: the mark, the one thing an author would have reached for `<mark>` to do, has its own syntax. Commonmarker's safe mode also empties `javascript:`, `vbscript:` and `file:` URLs, and every `data:` URL except those whose media type starts with `image/png`, `image/gif`, `image/jpeg` or `image/webp`, ignoring case, on links and images alike. The match is a prefix, so `data:image/pngx` and `data:image/png+xml` are kept as well. Keeping what Commonmarker keeps, with no URL filter of our own, was the owner's decision (2026-10-08). A raster image cannot run script. The prefix is harmless because whatever follows it, the media type is still an `image/` type that names no format a browser executes: the browser decodes it as an image or shows nothing. The `data:` types that can carry script, `image/svg+xml` and `text/html`, don't match and stay emptied. Also, browsers block top-level navigation to `data:`, an inline image makes no network request and so can track less than the `https:` images already allowed, and stripping them would take a URL filter the site otherwise doesn't need. `tagfilter` is kept as a second line in case `unsafe` is ever turned on. Obligations: MR-4, MR-5.

### D-7. A mark may span inline formatting (change request)

**Decision.** A mark pairs its `==` across inline elements in the same block and wraps them whole, as long as both ends sit in the same element. A pair that would straddle an element edge does not form, and its equals signs stay visible.

**Derivation.**
- *Why span at all.* A phrase worth marking often contains a stressed word, a link or a code term. Today `==a *b* c==` shows its equals signs, because the mark is found one text node at a time and the emphasis splits the phrase into two nodes. The tree-based approach (D-1) is kept; only the unit of search widens from a text node to an element's inline content.
- *Why formatting is kept inside.* The mark is emphasis layered on the text, not a replacement for its formatting. Dropping the `<em>` or the link would lose the author's other intent.
- *Why both ends in the same element.* `<mark>` must nest properly. A pair straddling an edge could be rescued by splitting it into several marks (one outside the link, one inside), but every preset draws a mark as one instrument (a swipe, a strip of tape), and a split pair draws as two with a seam. Such a pair is almost always a typo in the source. Leaving the equals signs visible shows the author the mistake in the preview, where silently reshaping it would not.
- *Why code is wholly inside or not at all.* A code span is atomic: it is never split, so a mark can contain it whole but cannot open or close inside it (D-1).
- *Why pairing is per element.* `<mark>` must nest properly, so a pair can only form between delimiters in the same element. Counting each child as one non-space character keeps the `mark` rule (D-4) unchanged inside an element, so an author who can predict `mark` on the words around an element can predict the paragraph. Omitted raw HTML counts the same way: it is a node in the tree, and ignoring it lets the two halves of `=<i>=` read as one delimiter. The enclosing element pairs first, so an outer mark wins over a pair inside a child; a mark inside a mark would draw as two instruments over each other. This changes one case that works today: `==a *b* ==c==` now marks `a <em>b</em> ==c` instead of only `c`.
- *Why line breaks are included.* A soft line break is inline content and renders as a space. Posts written at a fixed width break lines mid-phrase, and a mark that silently fails at the wrap point is the same bug as the one this request fixes.

Obligations: MR-17 to MR-20.

## The language

### D-8. The language control is a form that PATCHes, not a link

**Decision.** Each footer button is a `button_to`-style form that posts to `/locale` with `_method=patch`; `LocalesController#update` sets the cookie and answers `303 See Other`.

**Derivation.** Choosing a language changes stored state, so it is not a GET. A link such as `/locale?l=es` would also be followed by things that are not the visitor: Turbo prefetches a link on hover, and crawlers follow every link, so hovering over "Español" could switch the site. A form needs no JavaScript, which `ASK.md` §4.9 requires of the whole surface. The redirect is `303` rather than Rails' default `302` because the follow-up must be a GET whatever method the browser sent, and `303` is the status that says so; Turbo expects it after a form submission. Obligations: LC-6, LC-7, LC-10.

### D-9. Back where the visitor was; home when that is unknown or foreign

**Decision.** The redirect goes to the `Referer` when it is on this host, else to the home page (`redirect_back_or_to root_path`). An unknown code changes nothing and redirects the same way.

**Derivation.** The visitor pressed the button to read the page they were on in another language, so that page is the destination. The `Referer` is supplied by the request, so following it to another host would make `/locale` an open redirect; Rails refuses other hosts in `redirect_back_or_to` and falls back. An unknown code can only come from a stale page or a hand-written request; an error page punishes the first and tells the second nothing, so the request is treated as a no-op. Only the exact codes the buttons send are accepted: `ES` is not one of them, and accepting it would mean the control normalises codes that nothing it renders ever sends. Obligations: LC-7, LC-8, LC-9.

### D-10. `Accept-Language` is read in the order sent

**Decision.** The first entry whose language is a site language wins; `q` weights are not used to re-sort. This is the behaviour the shell shipped, pinned as it is.

**Derivation.** Browsers emit entries already in descending preference, so re-sorting changes nothing for a real browser and only matters for a hand-written header. With two site languages the first match is also the only decision there is to make. Obligation: LC-2.

### D-11. Each button names its language in that language

**Decision.** The buttons read "English" and "Español" on every page, each with `lang`, and the current one is marked with `aria-pressed`.

**Derivation.** The control exists for the visitor who landed in the wrong language (`ASK.md` §4.8: Spanish browsers already get Spanish), so the label they need is the one in the language they read, not a translation into the one they cannot. `lang` on the button lets a screen reader switch voice for the one word. The pressed state is the mode toggle's pattern: one stable name per button plus a state, so the current language is stated in text to assistive technology and never by hue alone. Obligations: LC-10.

## The home page

### D-12. Old shell URLs land on the plain home page

**Decision.** `/?line=...` renders the home page as if the parameter were absent. `/shell` is removed with its route and answers 404.

**Derivation.** `/?line=` links were the shell's shareable form and may be in messages and bookmarks; ignoring the parameter costs nothing and lands the visitor on a working page. `/shell` was only ever a form target that redirected or answered a stream, so nothing links to it directly, and a route kept only to redirect would be shell code that outlives the shell. Obligation: HP-5.

## Retiring the shell's settings

### D-13. A data migration, in SQL, for exactly three keys, with a no-op rollback

**Decision.** `RemoveShellSettings` runs one `DELETE` against `site_settings` for the three keys by name. `down` does nothing.

**Derivation.** Removing the defaults from `SiteSetting::DEFAULTS` is not enough: `all_settings` merges stored rows over the defaults, so a database where the owner ever saved the settings form keeps all three as live fields. Seeds are not run on deploy, so the change has to be a migration. It names the table and not the model because the model is application code that keeps changing after the migration is written. It names the keys rather than a `shell_%` pattern because a pattern is a guess about rows nobody has looked at. Rollback restores nothing because the rows held copy for a component that is gone; raising `IrreversibleMigration` instead would only stop someone rolling back past it for an unrelated reason. Obligations: DM-1 to DM-4.
