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

## Contract: the language

Which language a public page is in, and how a visitor changes it. Resolution lives in `SiteController`, which every public controller inherits; the control is `LocalesController#update` at `PATCH /locale` and a pair of buttons in the footer. Every obligation below has a test of the same number in `test/contract/locale_contract_test.rb`. LC-1 to LC-5 shipped with the shell and survive its removal; LC-6 to LC-11 are the footer control that replaces the shell's `lang` command (`ASK.md` §4.8). Decisions and their derivations are in `DECISIONS.md`.

**Which language a page is in** (shipped)

- **LC-1** A `locale` cookie naming a site language (`en` or `es`) decides, whatever the browser asks for, on every public page, and the page says which on `<html lang>`. *Because* the cookie is a choice the visitor made on this site, and the browser's setting is a guess made for every site.
- **LC-2** Without that cookie, `Accept-Language` decides: the first entry, in the order the browser sent them, whose language (the part before any region, `es` in `es-AR`, case ignored) is a site language. Entries are separated by commas, with or without whitespace: `fr,es` and `fr, es` both give Spanish. The `q` weights are not used to re-sort. *Because* browsers already send entries in their order of preference.
- **LC-3** Otherwise English. A cookie or an entry naming a language the site does not have is skipped as if it were absent, so an unknown cookie still lets `Accept-Language` decide. A malformed header renders the page in English rather than failing. *Because* no request is refused or broken over its language.
- **LC-4** The login, password-reset and admin pages are in English whatever the cookie or the browser says, and the admin offers no language control. *Because* the admin has one user, who writes in English, and its strings are not in the locale files.
- **LC-5** `config/locales/en.yml` and `es.yml` have the same tree of keys. *Because* a key missing from one shows that language's visitors a "translation missing" string.

**Choosing a language** (task 1)

- **LC-6** `PATCH /locale` with `locale` set to `en` or `es` sets the `locale` cookie to that code. The cookie is permanent (it has an expiry years away, not the browser session), `SameSite=Lax` and `HttpOnly`. *Because* a visitor who chose Spanish once should be greeted in Spanish next time, and a link followed from another site should arrive in the language they chose. Only the server reads it, so no script needs to (settled 2026-10-09).
- **LC-7** The reply is a `303 See Other` back to the page the request came from (its `Referer`, path and query kept). *Because* changing language should not move the visitor, and the follow-up request must be a GET whatever method the form used.
- **LC-8** With no `Referer`, or one on another host, the redirect is to the home page, still with `303`. *Because* redirecting to an address the request supplied is an open redirect.
- **LC-9** Any other `locale` (unknown, a different case such as `ES`, blank, or missing) sets no cookie, so an earlier choice stays, and the reply still redirects as LC-7 and LC-8. *Because* a stale form or a hand-written request should land the visitor back where they were, not on an error page; resolution ignores unknown codes the same way (LC-3).
- **LC-10** Every public page's footer holds the control: one group (`role="group"`) named "Language" in English and "Idioma" in Spanish, holding two buttons, English then Spanish. Each button is the submit button of its own form, which posts to `/locale` with `_method=patch` and its code as `locale`, so it works without JavaScript. Each is labelled with its language's own name, "English" and "Español", whatever the page's language, and carries `lang` for that language. The button for the page's language has `aria-pressed="true"` and the other `aria-pressed="false"`. *Because* a visitor who cannot read the current language must still recognise their own; `lang` has a screen reader pronounce "Español" as Spanish; and which one is current has to be stated in more than hue (Accessibility, above), the same way the mode toggle states it.
- **LC-11** Pressing a footer button brings the same page back in that language, and every public page after it stays in that language. *Because* that is the control's whole job, end to end, over plain HTTP.

## Contract: the home page

What the home page is once the shell is gone and before the copy replaces it (`PLAN.md` task 2 rewrites this section). `HomeController#show` renders it. Every obligation below has a test of the same number in `test/contract/home_page_contract_test.rb`. HP-1 to HP-3 are what the page already shows besides the shell, pinned so that the deletion takes the shell and nothing else; HP-4 and HP-5 are the shell's removal.

- **HP-1** The page's one `<h1>` is the tagline in the page's language (`SiteSetting.localized("tagline")`), with its `==marks==` drawn as `<mark>`. The hero note (`hero_note`, `hero_note_es`), when there is one, sits in the hero's rail. The document title is the site title.
- **HP-2** Below the hero come the visible home sections in position order, each with its heading as an `<h2>`, its note, and its body rendered as Markdown. Position decides the order, not when a section was created: a home section created last with the lowest position comes first. Hidden sections and other pages' sections are absent.
- **HP-3** Then the three most recently published posts, newest first, each a link to its post with its publication date in a `<time>`, and a link to all writing. Drafts never appear. With nothing published there is no list and no heading for one.
- **HP-4** The page has no command line: no form and no text field other than the footer's language control, no typed opening, and no script controller besides the header's theme controls. *Because* the shell is replaced (`ASK.md` §11), and until the invitation arrives the page has to be complete for someone who never types.
- **HP-5** Query parameters change nothing on the page: `/?line=whoami` renders what `/` renders and echoes nothing from the URL. *Because* links to the shell's old URLs are out in the world and should land on a working page.

## Contract: the post page

The public post at `/writing/:slug` renders through the site layout. Obligations run in `test/contract/post_page_contract_test.rb`.

- **PP-1** When a post has an excerpt, its description and Open Graph description are that excerpt with `==marks==` removed and HTML escaped exactly once, preserving literal entity text. *Because* writing travels through link previews, and double escaping makes an excerpt such as `a < b ==c==` read as `a &lt; b c` instead of `a < b c` (pilot finding F-19).

## Contract: retiring the shell's settings

The shell's copy lived in three `site_settings` rows. A data migration removes them, because seeds are not a deploy step and a migration is. Every obligation below has a test of the same number in `test/contract/remove_shell_settings_contract_test.rb`.

- **DM-1** One migration, `db/migrate/<timestamp>_remove_shell_settings.rb`, defining `RemoveShellSettings`, deletes the rows whose key is `shell_opening`, `shell_whoami` or `shell_whoami_es`, and changes no other row. *Because* a stored row outlives its default: the admin's settings form lists every stored key, so the rows would otherwise stay there as three fields that change nothing.
- **DM-2** It runs cleanly on a database that never had the rows, and twice in a row. Rolling it back raises nothing and restores nothing. *Because* most databases never stored an override, and copy for a deleted component has nothing to come back to; an irreversible migration would only block rolling back past it.
- **DM-3** It works on the table in SQL and never names the `SiteSetting` model. *Because* a migration runs against whatever the model is on the day it runs, and a model it leaned on may since have changed.
- **DM-4** Afterwards the admin's settings page offers no field for any of the three, and `SiteSetting` has no value or default for them. The other settings are still offered. *Because* that is where the owner would otherwise meet the shell again.

## Contract: the consulting page

The approved consulting brief is implemented at `/consulting`. Obligations run in
`test/contract/consulting_page_contract_test.rb`. Navigation, English in both
locales, and seeded content are provisional defaults, pending the owner's decision.

- **CP-1** `/consulting` is public without login. Its one h1 is “Agustín Calabrese: agentic development and AI-native systems”. The intro, two numbered offers (including the four bullets and Troupe paragraph), and Background preserve the approved words and order, with no extra claims, placeholders, prices, formats, or em/en dashes. The intro leads with the systems built since 2025 and help for teams, then the 2024 change, because the owner approved that order (D3). Existing Markdown typography may curl the intro's apostrophe. *Because* this is approved copy, not an invitation to rewrite it.
- **CP-2** The copy is seeded as editable consulting Sections, rendered through the existing section partial: only visible consulting sections, in position then id order, guaranteed regardless of the database scan direction. *Because* the owner manages static copy at `/admin`, and changing one page must not expose another page's content or hidden text.
- **CP-3** `github.com/ag0os/troupe` links to `https://github.com/ag0os/troupe`. After Background, the only contact line is “Want to talk about your team? Get in touch on LinkedIn.”, with LinkedIn linked to the current `SiteSetting["linkedin_url"]`, opening in a new tab with `target="_blank"` and `rel="noopener"` as on Contact. *Because* the public repository is the proof and the owner's configured profile is the contact destination, with the site's existing external-link behavior.
- **CP-4** The document and Open Graph title use the approved heading followed by the site title; description and Open Graph description use the visible consulting intro, with marks removed and whitespace collapsed, falling back to the layout's description when absent. Text outputs are escaped, never HTML. *Because* a shared link must identify this page and edits must not inject markup into the head.
- **CP-5** English copy appears under both locales, with the normal locale-specific chrome, language control and theme controls, and no link to `/consulting` in the primary nav. The copy container declares `lang="en"`. *Because* the owner decided on 2026-10-13 that the page is reached from links in the site's copy rather than the primary nav (reversing the nav half of D5), Spanish translation is deferred (D6), and assistive technology needs the prose's actual language.

## Contract: seeded copy

These obligations apply to the first-deploy copy loaded by `db/seeds.rb`, with
tests in `test/contract/seeded_copy_contract_test.rb` that run the real seeds.
The owner can still edit the wording in `/admin`; individual sentences are not
pinned by this contract.

- **SC-1** The seeded public site neither names Claude Forge nor links to `ag0os/claude-forge`. *Because* the retired toolkit must not send visitors to superseded proof.
- **SC-2** The seeded Work open-source section links Troupe to `https://github.com/ag0os/troupe`. *Because* visitors evaluating the current toolkit need its public repository.
- **SC-3** The seeded About bio links to `/consulting`, and following that link reaches a public page successfully. *Because* the invitation to consulting must lead to an offer the visitor can read without login.
- **SC-5** The footer CTA in both locales, the Contact page's intro and the About bio each link to `/consulting`. *Because* the owner decided on 2026-10-13 that the consulting page is reached from these entry points rather than the primary nav.
- **SC-6** The seeds plant no posts: loading them leaves the posts exactly as they were, so a freshly seeded site has none. *Because* the owner does not want a template post on the live site; the first post is one the owner writes (settled 2026-10-14).

## Contract: writing

Where the writing shows before there is any. Obligations run in `test/contract/writing_contract_test.rb`. A post counts as published when `Post.published` includes it: status published, with a publication date. Decisions are in `DECISIONS.md` (D-15, D-16).

- **WR-1** The header's primary nav links to Writing only while at least one post is published, in both languages. With only drafts, or no posts at all, the link is absent; the first published post brings it back with no setting to change. The home page's Writing block follows the same rule (HP-3). *Because* the owner decided on 2026-10-14 that Writing appears by itself when the first post is published, and a nav link to an empty page is a promise the site cannot keep yet.
- **WR-2** `/writing` stays public and answers 200 with nothing published, showing the empty state "First essays coming soon." and no post list. Without a nav link (WR-1) it is reached only by its address. *Because* the address may already be shared or bookmarked, and a 404 there reads as a broken site.
- **WR-3** `/feed` stays public and answers 200 with nothing published: a valid Atom feed (`application/atom+xml`, with an `id`, a `title` and an `updated`) and no entries. *Because* feed readers poll it, and an error or a malformed document can make a reader drop the subscription before the first post arrives.
- **WR-4** The site layout's head links to the feed (`<link rel="alternate" type="application/atom+xml">`) whether or not anything is published. *Because* the link is for feed readers, not visitors: it adds nothing to the page, and a subscription taken early delivers the first post when it lands. The empty feed is valid (WR-3). Provisional default, pending the owner's decision.

## Contract: the production deploy

What the first deploy to agoos.dev depends on. Obligations run in `test/contract/production_contract_test.rb`, and PD-5 in `test/contract/canonical_host_contract_test.rb`. Decisions are in `DECISIONS.md` (D-17 to D-19).

- **PD-1** In production, `db/seeds.rb` raises unless `ADMIN_PASSWORD` is set and not blank, with a message that names `ADMIN_PASSWORD`, before it writes anything: no user, section, setting or post. That holds whether or not the admin user already exists. *Because* the repository is public, so the development default password is public, and an admin created with it on the live site is an open door. Failing before the first write leaves the database as it was, so setting the variable and seeding again is the whole fix.
- **PD-2** In production with `ADMIN_PASSWORD` set, seeding creates the admin with that password, and nothing it prints contains the password. *Because* deploy output goes to logs that outlive the session, and a password in a log is shared with whoever reads the log.
- **PD-3** In development and test, seeding without `ADMIN_PASSWORD` creates the admin with the default password, `change-me-please`, and prints it. *Because* a local database needs an admin someone can log in as without setup.
- **PD-4** In production, links in mail are built for `https://agoos.dev`: the password-reset link is `https://agoos.dev/passwords/<token>/edit`. The test boots the production environment in a separate process and builds the link there. *Because* the password-reset mail is the only way back into the admin, and a link to `example.com` leads nowhere. `.dev` is HTTPS only (HSTS preloaded), so an `http` link would depend on the browser to upgrade it.
- **PD-5** Any request to host `www.agoos.dev`, whatever its method or path, answers a permanent redirect (301) to `https://agoos.dev` with the same path and query string. Requests to `agoos.dev` are unaffected. *Because* the site should have one canonical address, so it doesn't appear twice to visitors and search engines. The owner chose to do this in the app rather than in the server's Caddy config (2026-10-16), following Hatchbox's documented approach: a host-constrained route placed first in `config/routes.rb`.

## Contract: continuous integration

What a green `ci` check on a pull request means. `bin/ci` runs the steps in `config/ci.rb`, and GitHub runs exactly `bin/ci`. A merge with nobody reading the code rests on this check alone, so it runs every check that would otherwise be run by hand. Obligations run in `test/contract/ci_contract_test.rb`. CI-1 to CI-3 are read from the config files, and CI-4 and CI-5 are run on hand-built mutant results. Decisions are in `DECISIONS.md` (D-20 to D-23).

- **CI-1** `bin/ci` runs setup, RuboCop, the gem and import-map audits, Brakeman, the Rails tests, the system tests, the seeds, and then three floors: mutation (`bin/mutant-floor`), duplication (`bin/exhale dry --introduced-only`) and complexity (`bin/exhale complexity`). Every step runs even after one fails, and the run fails if any step did. *Because* one run should list every failure, and a check left out of `bin/ci` is a check nobody runs before an unattended merge.
- **CI-2** GitHub runs one job, named `ci`, on every pull request and every push to main. Its only command besides installing libvips is `bin/ci`. It checks out the full history, and keeps the system tests' screenshots and mutant's full output when it fails. *Because* branch protection requires a check by name, and a second list of steps in the workflow would drift from `bin/ci`. The floors diff against the base, so they need its history.
- **CI-3** The floors judge only what changed since a base: on a pull request, the merge base with the target branch; on a push to main, the commit main pointed at before the push; locally, `origin/main` (fetch first), or `$CI_BASE`. *Because* main compared with itself has nothing to check and passes vacuously. Comparing a push with the main it replaced checks again what the merge actually produced.
- **CI-4** The mutation floor runs mutant on the subjects in `config/mutant.yml` that the change touches. It runs every subject when the change touches something that can let a mutation live without changing its subject: `config/mutant.yml`, `Gemfile.lock`, `test/mutant/`, the fixtures, `test/test_helper.rb`, or a test that declares `cover`. It fails on any surviving mutation that `test/mutant/baseline.yml` doesn't list, and on a neutral mutation the tests fail. A survivor is known by its subject and the lines its mutation removes and adds, so moving a method, or editing another, keeps its entry; each entry accepts one survivor. A timeout counts as a kill, as it does in mutant. An entry whose mutation is now killed is reported and doesn't fail. *Because* the floor is what is already accepted, and anything below it is new. Line numbers would make every edit above a method look like a new survivor.
- **CI-5** A change that alters the baseline's survivors must append an anchor giving its reason. `bin/mutant-floor --record "REASON"` runs every subject and writes the baseline, keeping earlier anchors. *Because* accepting a survivor is a decision, and its reason belongs in the file that records it.
- **CI-6** The duplication floor fails on a copy the change introduces, or one it pushes over the threshold (exhale's defaults: a score of 0.80, 4 lines, 20 normalised nodes). Copies already on main are listed as warnings. A deliberate copy passes only with a `parallel` clause in exhale's Contract (`contract/<primitive>/duplication.md`), whose section gives the reason. The complexity floor fails when a method's cognitive complexity rises above 8, or a new method starts above it, unless a `ceiling` clause gives a reason. *Because* both judge the change, not the codebase, and the merge base is the floor: main only gets there through this check.

What this does not cover: mutation runs only on the subjects listed in `config/mutant.yml`, the ones with a Contract test that declares `cover`. Code outside them is tested but not mutated.
