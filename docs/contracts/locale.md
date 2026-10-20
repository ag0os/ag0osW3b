---
component: locale
covers:
  - app/controllers/site_controller.rb
  - app/controllers/locales_controller.rb
  - app/views/shared/_footer.html.erb
  - app/models/section.rb
  - app/views/shared/_section.html.erb
  - app/views/shared/_header.html.erb
  - app/views/shared/_theme_controls.html.erb
  - app/views/admin/sections/_form.html.erb
  - app/controllers/admin/sections_controller.rb
  - config/routes.rb
  - app/helpers/localized_links_helper.rb
  - app/views/layouts/application.html.erb
  - app/views/posts/feed.atom.builder
  - app/views/posts/show.html.erb
  - config/locales/
depends_on:
  - markdown_renderer
tests:
  - test/contract/locale_contract_test.rb
  - test/contract/locale_urls_contract_test.rb
  - test/contract/locale_controllers_contract_test.rb
  - test/contract/locale_negotiation_contract_test.rb
  - test/contract/locale_browser_contract_test.rb
  - test/contract/locale_navigation_contract_test.rb
  - test/contract/locale_scope_contract_test.rb
  - test/contract/locale_vary_contract_test.rb
---
Coverage: 23 obligations; 23 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the language

Which language a public page is in, and how a visitor changes it. Resolution lives in `SiteController`, which every public controller inherits; the control is `LocalesController#update` at `PATCH /locale` and a pair of buttons in the footer. LC-1 to LC-5 shipped with the shell and survive its removal; LC-6 to LC-11 are the footer control that replaces the shell's `lang` command (`ASK.md` §4.8). LC-12 to LC-16 are what a page in Spanish reads: its chrome from the locale files, its sections from their Spanish columns, its dates, and the admin fields that hold the Spanish (`PLAN.md` task 9). Posts stay as written. Decisions and their derivations are in `docs/decisions/locale.md`.

## Which language a page is in

### LC-1 The path decides, then the locale cookie

A language address renders its path language regardless of cookie, browser or query. On a bare public address, a `locale` cookie naming a site language (`en` or `es`) decides whatever the browser asks for. HTML declares the rendered language on `<html lang>`. (D-33)

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** The cookie is a choice the visitor made on this site, and the browser's setting is a guess made for every site.

Kind: functional. Proof: test, tests named LC-1 in `test/contract/locale_contract_test.rb` and `test/contract/locale_negotiation_contract_test.rb`.

### LC-2 On a bare address without the cookie, Accept-Language decides, in the order sent

On a bare address without a valid locale cookie, `Accept-Language` decides: the first entry, in the order the browser sent them, whose language (the part before any region, `es` in `es-AR`, case ignored) is a site language. Entries are separated by commas, with or without whitespace: `fr,es` and `fr, es` both give Spanish. The `q` weights are not used to re-sort.

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** Browsers already send entries in their order of preference. (D-10)

Kind: functional. Proof: test, tests named LC-2 in `test/contract/locale_browser_contract_test.rb` and `test/contract/locale_negotiation_contract_test.rb`.

### LC-3 On a bare address, otherwise English

On a bare address, otherwise English. A path language takes precedence over these fallbacks. A cookie or an entry naming a language the site does not have is skipped as if it were absent, so an unknown cookie still lets `Accept-Language` decide. A malformed header renders the page in English rather than failing.

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** No request is refused or broken over its language.

Kind: functional. Proof: test, tests named LC-3 in `test/contract/locale_contract_test.rb`, `test/contract/locale_negotiation_contract_test.rb` and `test/contract/locale_browser_contract_test.rb`.

### LC-4 Login, password reset and the admin are in English

The login, password-reset and admin pages are in English whatever the cookie or the browser says, and the admin offers no language control.

**Reason.** The admin has one user, who writes in English, and its strings are not in the locale files.

Kind: functional. Proof: test, the two tests named LC-4 in `test/contract/locale_contract_test.rb`.

### LC-5 The two locale files have the same tree of keys

`config/locales/en.yml` and `es.yml` have the same tree of keys.

**Reason.** A key missing from one shows that language's visitors a "translation missing" string.

Kind: functional. Proof: test, LC-5 in `test/contract/locale_contract_test.rb`.

## Choosing a language

### LC-6 PATCH /locale sets a permanent cookie

`PATCH /locale` with `locale` set to `en` or `es` sets the `locale` cookie to that code. The cookie is permanent (it has an expiry years away, not the browser session), `SameSite=Lax` and `HttpOnly`.

**Reason.** A visitor who chose Spanish once should be greeted in Spanish next time, and a link followed from another site should arrive in the language they chose. Only the server reads it, so no script needs to (settled 2026-10-09). (D-8)

Kind: functional. Proof: test, the two tests named LC-6 in `test/contract/locale_contract_test.rb`. Focused controller proofs also run in `test/contract/locale_controllers_contract_test.rb`.

### LC-7 The reply is a 303 to the counterpart page

A valid choice answers `303 See Other` to the same public page at the chosen language’s address. The destination is rebuilt from recognised public GET route parameters, and the original raw query is appended without interpreting it as URL options. A root-relative public referrer is usable. (D-33, D-35)

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** Changing language should not move the visitor, and the follow-up request must be a GET whatever method the form used. (D-8, D-9)

Kind: functional. Proof: test, tests named LC-7 in `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`. Focused controller proofs also run in `test/contract/locale_controllers_contract_test.rb`.

### LC-8 An unusable referrer goes to the chosen-language home

With a valid choice, a missing, foreign, protocol-relative, user-info-bearing, malformed, unknown or non-public referrer, a scheme other than http/https, or a port different from the request’s, redirects to the chosen-language home with `303`. The redirect stays local and never raises over an unusable referrer. Rails’ open-redirect policy remains `:raise`, so its default independently refuses external redirect destinations. (D-35)

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** Redirecting to an address the request supplied is an open redirect. (D-9)

Kind: functional. Proof: test, tests named LC-8 in `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`. Focused controller proofs also run in `test/contract/locale_controllers_contract_test.rb`.

### LC-9 An invalid choice sets no cookie and keeps a safe original address

Any other `locale` (unknown, a different case such as `ES`, blank, or missing) writes no cookie, preserving an earlier choice. A safe public referrer returns to its own path locale, or remains bare, with its raw query preserved; otherwise the destination is bare `/`. The reply is always `303`, never a language-choice error. (D-35)

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** A stale form or a hand-written request should land the visitor back where they were, not on an error page; resolution ignores unknown codes the same way (LC-3). (D-9)

Kind: functional. Proof: test, tests named LC-9 in `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`. Focused controller proofs also run in `test/contract/locale_controllers_contract_test.rb`.

### LC-10 The footer holds the control

Every public page's footer holds the control: one group (`role="group"`) named "Language" in English and "Idioma" in Spanish, holding two buttons, English then Spanish. Each button is the submit button of its own form, which posts to `/locale` with `_method=patch` and its code as `locale`, so it works without JavaScript. Each is labelled with its language's own name, "English" and "Español", whatever the page's language, and carries `lang` for that language. The button for the page's language has `aria-pressed="true"` and the other `aria-pressed="false"`.

**Reason.** A visitor who cannot read the current language must still recognise their own; `lang` has a screen reader pronounce "Español" as Spanish; and which one is current has to be stated in more than hue (`PRODUCT.md`, "Accessibility & Inclusion"), the same way the mode toggle states it. (D-8, D-11)

Kind: functional. Proof: test, the five tests named LC-10 in `test/contract/locale_contract_test.rb`.

### LC-11 Pressing a button opens the counterpart in that language

Pressing a footer button brings a fresh response of the same page at its address in the chosen language; every public page linked from it keeps that language. A later explicit language address renders its own language. (D-33, D-35)

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

**Reason.** That is the control's whole job, end to end, over plain HTTP.

Kind: functional. Proof: test, tests named LC-11 in `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`.

## What a page in Spanish reads

### LC-12 No English chrome on a Spanish page

On a page in Spanish, no string that `config/locales/en.yml` gives in English, where `es.yml` gives something different, appears in what a reader gets: the text outside scripts, the `aria-label`, `title`, `alt` and `placeholder` attributes, and the description and Open Graph title and description. A string with placeholders (`%{name}`, `%b`) is checked piece by piece. This holds on the home page, About, Work, Contact, Consulting, Writing with and without anything published, a post, and the feed.

**Reason.** A visitor who chose Spanish, or whose browser asked for it, should not find the page switching back to English in its chrome. Checking against `en.yml` itself means a string added to both files later is covered the day it is added. (D-27)

Kind: functional. Proof: test, the three tests naming LC-12 across `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`.

### LC-13 Public templates write no words of their own

The public templates (`app/views/home`, `pages`, `posts`, `shared` and the site layout) write no word themselves, only through `t()`, settings or content. That covers words in their markup's text, words in the `aria-label`, `title`, `alt` and `placeholder` attributes, and capitalised words in the string literals of their Ruby. The exceptions are the proper nouns English, Español, GitHub and LinkedIn.

**Reason.** LC-12 only catches strings that are already in the locale files. A label typed straight into a template, such as the header nav's `aria-label="Primary"`, which this check found, never reaches `en.yml`, so no comparison with `es.yml` could see it. The scan reads every template, so a string added later cannot slip past it either. (D-27)

Kind: functional. Proof: test, the two tests named LC-13 in `test/contract/locale_contract_test.rb`, one over the templates and one showing the scan finds a word in each place it looks.

### LC-14 A section reads in the page's language, and its English says it is English

A section's heading, note and body show their Spanish column (`heading_es`, `note_es`, `body_es`) on a page in Spanish. A Spanish field left blank shows the English instead, on an element marked `lang="en"`; a field shown in the page's language carries no `lang` of its own. A page in English shows the English columns and never the Spanish.

**Reason.** The home page's copy, and every page's, is its sections, so this is what makes the site read in Spanish (`ASK.md` §4.8). A blank field falling back to English keeps a half-translated section readable instead of empty, and `lang` has a screen reader read that English as English. (D-27)

Kind: functional. Proof: test, the four tests naming LC-14 across `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`.

### LC-15 Dates and the feed read in the page's language

Post dates read in the page's language: "Oct 19, 2026" and "19 oct 2026" in the lists on the home page and Writing, "October 19, 2026" and "19 de octubre de 2026" on a post. The feed declares the page's language (`xml:lang`), and its title and subtitle are in it. The subtitle is the tagline as plain text, with its marks removed.

**Reason.** An English month on a Spanish page is chrome like any other. The month names live in the locale files, so no gem is needed (`PLAN.md` task 9). (D-27)

Kind: functional. Proof: test, the three tests naming LC-15 across `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`.

### LC-16 The admin edits a section's Spanish

The admin's section form has fields for the Spanish heading, note and body. Saving it stores them, and editing the section shows them again. The form's labels stay in English (LC-4).

**Reason.** Content is edited at `/admin`, not in code, so the Spanish has to be too. (D-27)

Kind: functional. Proof: test, LC-16 in `test/contract/locale_contract_test.rb`.

### LC-17 Editable page copy falls back field by field

On a Spanish page, each editable copy field uses its Spanish default when its row is missing, and its English value when the saved Spanish is blank. English fallback declares `lang="en"` on its prose element; translated prose has no language override. English pages never use Spanish copy. Link labels follow the actual prose language.

**Reason.** Defaults keep production translated without a data step, and a saved blank requests the same readable, correctly pronounced fallback as sections. (D-30, D-31)

Kind: functional. Proof: test, the two tests naming LC-17 across `test/contract/locale_contract_test.rb` and `test/contract/locale_urls_contract_test.rb`.

## Language addresses and representations

### LC-18 Every public page has an English and a Spanish address

Home, About, Work, Contact, Consulting, Writing and each published post have `/en` and `/es` addresses that always render their path language on `<html lang>`, regardless of cookie, browser or query. Each language’s feed declares its `xml:lang`. Unknown language prefixes are 404. Admin, authentication, health and the PATCH language control remain unprefixed. Admin Copy offers deterministic “View English” and “View Spanish” links.

**Reason.** Outreach and search need addresses that always mean their language; the editor must be able to inspect each. (D-33)

Kind: functional. Proof: test, tests named LC-18 in `test/contract/locale_urls_contract_test.rb` and `test/contract/locale_scope_contract_test.rb`.

### LC-19 Bare addresses negotiate in place, privately

On fresh HTML and Atom responses, bare addresses negotiate by LC-1 to LC-3, answer in place without a language redirect and add Accept-Language to Vary without dropping other fields. Every address carries Cache-Control containing private; prefixed addresses do not add Accept-Language to Vary and preserve other fields.

**Reason.** A guessed language must not move an existing address or enter a shared cache. (D-33)

Kind: functional. Proof: test, tests named LC-19 in `test/contract/locale_urls_contract_test.rb` and `test/contract/locale_vary_contract_test.rb`.

### LC-20 Every public HTML page links its language versions

At every address of a page, the canonical is the query-free address of its rendered language and og:url equals it. All versions list the same en/es hreflang set including themselves and x-default at the bare address. Open Graph locale is en_US or es_AR for the rendered representation, with the other as alternate.

**Reason.** Reciprocal language links identify each representation and the bare selector for search and previews. (D-34)

Kind: functional. Proof: test, LC-20 in `test/contract/locale_urls_contract_test.rb`.

### LC-21 Public links keep the rendered language

Generated public links and recognised single-slash public links inside rendered section/post Markdown, including Atom entry content, use the rendered language’s path. Already-prefixed authored links follow it too; raw query and fragment are preserved, and query keys never configure URL generation. Stored prose is unchanged. Other authored destinations stay as written; external, admin, authentication, health and control links remain unprefixed without a locale query. Copy’s preview links explicitly name their language.

**Reason.** Readers should stay in the language they are reading without binding stored prose to a URL layout. (D-33, D-34)

Kind: functional. Proof: test, tests named LC-21 in `test/contract/locale_urls_contract_test.rb` and `test/contract/locale_navigation_contract_test.rb`.

### LC-22 English posts say they are English in another language

Every post is English. Its HTML title and body, and Atom entry title, summary and content, declare lang=en (xml:lang in Atom) when the rendered language is not English, including negotiated bare addresses. English representations carry no redundant content language override.

Reworded 2026-10-20 by refine: locale URLs (review fixes); flagged for owner review.

**Reason.** Posts remain as written; assistive technology must pronounce their English as English within Spanish chrome. (D-34)

Kind: functional. Proof: test, LC-22 in `test/contract/locale_urls_contract_test.rb`.

### LC-23 Each feed identifies its language explicitly and keeps stable ids

A feed’s HTML alternate is the rendered-language Writing page, its self URL is that language’s format-free feed address, and the HTML head discovers that feed. English retains `tag:<host>,2005:/feed` at every serving address; Spanish uses `tag:<host>,2005:/es/feed`. Query and format aliases never change ids. Entries keep the same default ids across languages and link to posts in the feed language.

**Reason.** Existing subscriptions must retain their identity, and Atom defaults otherwise identify a bare HTML alternate and a query-dependent feed. (D-33)

Kind: functional. Proof: test, LC-23 in `test/contract/locale_urls_contract_test.rb`.

## Decisions

- D-33 to D-35, `docs/decisions/locale.md`: path languages, representations and safe counterpart redirects (LC-1 to LC-3, LC-7 to LC-9, LC-11, LC-18 to LC-23).

- D-30 and D-31, `docs/decisions/copy.md`: editable copy fallback and generated link labels (LC-17).

- D-8, `docs/decisions/locale.md`: the language control is a form that PATCHes, not a link (LC-6, LC-7, LC-10).
- D-9, `docs/decisions/locale.md`: back where the visitor was; home when that is unknown or foreign (LC-7, LC-8, LC-9).
- D-10, `docs/decisions/locale.md`: `Accept-Language` is read in the order sent (LC-2).
- D-11, `docs/decisions/locale.md`: each button names its language in that language (LC-10).
- D-27, `docs/decisions/locale.md`: Spanish sections are three columns that fall back field by field, and the interface chrome comes from the locale files (LC-12 to LC-16); editable prose is superseded by D-30.
