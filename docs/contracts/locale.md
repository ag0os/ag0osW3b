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
  - config/locales/
depends_on: []
tests:
  - test/contract/locale_contract_test.rb
---
Coverage: 17 obligations; 17 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the language

Which language a public page is in, and how a visitor changes it. Resolution lives in `SiteController`, which every public controller inherits; the control is `LocalesController#update` at `PATCH /locale` and a pair of buttons in the footer. LC-1 to LC-5 shipped with the shell and survive its removal; LC-6 to LC-11 are the footer control that replaces the shell's `lang` command (`ASK.md` §4.8). LC-12 to LC-16 are what a page in Spanish reads: its chrome from the locale files, its sections from their Spanish columns, its dates, and the admin fields that hold the Spanish (`PLAN.md` task 9). Posts stay as written. Decisions and their derivations are in `docs/decisions/locale.md`.

## Which language a page is in

### LC-1 The locale cookie decides

A `locale` cookie naming a site language (`en` or `es`) decides, whatever the browser asks for, on every public page, and the page says which on `<html lang>`.

**Reason.** The cookie is a choice the visitor made on this site, and the browser's setting is a guess made for every site.

Kind: functional. Proof: test, the two tests named LC-1 in `test/contract/locale_contract_test.rb`.

### LC-2 Without the cookie, Accept-Language decides, in the order sent

Without that cookie, `Accept-Language` decides: the first entry, in the order the browser sent them, whose language (the part before any region, `es` in `es-AR`, case ignored) is a site language. Entries are separated by commas, with or without whitespace: `fr,es` and `fr, es` both give Spanish. The `q` weights are not used to re-sort.

**Reason.** Browsers already send entries in their order of preference. (D-10)

Kind: functional. Proof: test, the four tests named LC-2 in `test/contract/locale_contract_test.rb`.

### LC-3 Otherwise English

Otherwise English. A cookie or an entry naming a language the site does not have is skipped as if it were absent, so an unknown cookie still lets `Accept-Language` decide. A malformed header renders the page in English rather than failing.

**Reason.** No request is refused or broken over its language.

Kind: functional. Proof: test, the four tests named LC-3 in `test/contract/locale_contract_test.rb`.

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

Kind: functional. Proof: test, the two tests named LC-6 in `test/contract/locale_contract_test.rb`.

### LC-7 The reply is a 303 back to the page

The reply is a `303 See Other` back to the page the request came from (its `Referer`, path and query kept).

**Reason.** Changing language should not move the visitor, and the follow-up request must be a GET whatever method the form used. (D-8, D-9)

Kind: functional. Proof: test, LC-7 in `test/contract/locale_contract_test.rb`.

### LC-8 No referrer, or a foreign one, goes home

With no `Referer`, or one on another host, the redirect is to the home page, still with `303`.

**Reason.** Redirecting to an address the request supplied is an open redirect. (D-9)

Kind: functional. Proof: test, the two tests named LC-8 in `test/contract/locale_contract_test.rb`.

### LC-9 Any other code sets no cookie and still redirects

Any other `locale` (unknown, a different case such as `ES`, blank, or missing) sets no cookie, so an earlier choice stays, and the reply still redirects as LC-7 and LC-8.

**Reason.** A stale form or a hand-written request should land the visitor back where they were, not on an error page; resolution ignores unknown codes the same way (LC-3). (D-9)

Kind: functional. Proof: test, the two tests named LC-9 in `test/contract/locale_contract_test.rb`.

### LC-10 The footer holds the control

Every public page's footer holds the control: one group (`role="group"`) named "Language" in English and "Idioma" in Spanish, holding two buttons, English then Spanish. Each button is the submit button of its own form, which posts to `/locale` with `_method=patch` and its code as `locale`, so it works without JavaScript. Each is labelled with its language's own name, "English" and "Español", whatever the page's language, and carries `lang` for that language. The button for the page's language has `aria-pressed="true"` and the other `aria-pressed="false"`.

**Reason.** A visitor who cannot read the current language must still recognise their own; `lang` has a screen reader pronounce "Español" as Spanish; and which one is current has to be stated in more than hue (`PRODUCT.md`, "Accessibility & Inclusion"), the same way the mode toggle states it. (D-8, D-11)

Kind: functional. Proof: test, the five tests named LC-10 in `test/contract/locale_contract_test.rb`.

### LC-11 Pressing a button brings the page back in that language

Pressing a footer button brings the same page back in that language, and every public page after it stays in that language.

**Reason.** That is the control's whole job, end to end, over plain HTTP.

Kind: functional. Proof: test, LC-11 in `test/contract/locale_contract_test.rb`.

## What a page in Spanish reads

### LC-12 No English chrome on a Spanish page

On a page in Spanish, no string that `config/locales/en.yml` gives in English, where `es.yml` gives something different, appears in what a reader gets: the text outside scripts, the `aria-label`, `title`, `alt` and `placeholder` attributes, and the description and Open Graph title and description. A string with placeholders (`%{name}`, `%b`) is checked piece by piece. This holds on the home page, About, Work, Contact, Consulting, Writing with and without anything published, a post, and the feed.

**Reason.** A visitor who chose Spanish, or whose browser asked for it, should not find the page switching back to English in its chrome. Checking against `en.yml` itself means a string added to both files later is covered the day it is added. (D-27)

Kind: functional. Proof: test, the two tests named LC-12 in `test/contract/locale_contract_test.rb`.

### LC-13 Public templates write no words of their own

The public templates (`app/views/home`, `pages`, `posts`, `shared` and the site layout) write no word themselves, only through `t()`, settings or content. That covers words in their markup's text, words in the `aria-label`, `title`, `alt` and `placeholder` attributes, and capitalised words in the string literals of their Ruby. The exceptions are the proper nouns English, Español, GitHub and LinkedIn.

**Reason.** LC-12 only catches strings that are already in the locale files. A label typed straight into a template, such as the header nav's `aria-label="Primary"`, which this check found, never reaches `en.yml`, so no comparison with `es.yml` could see it. The scan reads every template, so a string added later cannot slip past it either. (D-27)

Kind: functional. Proof: test, the two tests named LC-13 in `test/contract/locale_contract_test.rb`, one over the templates and one showing the scan finds a word in each place it looks.

### LC-14 A section reads in the page's language, and its English says it is English

A section's heading, note and body show their Spanish column (`heading_es`, `note_es`, `body_es`) on a page in Spanish. A Spanish field left blank shows the English instead, on an element marked `lang="en"`; a field shown in the page's language carries no `lang` of its own. A page in English shows the English columns and never the Spanish.

**Reason.** The home page's copy, and every page's, is its sections, so this is what makes the site read in Spanish (`ASK.md` §4.8). A blank field falling back to English keeps a half-translated section readable instead of empty, and `lang` has a screen reader read that English as English. (D-27)

Kind: functional. Proof: test, the three tests named LC-14 in `test/contract/locale_contract_test.rb`.

### LC-15 Dates and the feed read in the page's language

Post dates read in the page's language: "Oct 19, 2026" and "19 oct 2026" in the lists on the home page and Writing, "October 19, 2026" and "19 de octubre de 2026" on a post. The feed declares the page's language (`xml:lang`), and its title and subtitle are in it. The subtitle is the tagline as plain text, with its marks removed.

**Reason.** An English month on a Spanish page is chrome like any other. The month names live in the locale files, so no gem is needed (`PLAN.md` task 9). (D-27)

Kind: functional. Proof: test, the two tests named LC-15 in `test/contract/locale_contract_test.rb`.

### LC-16 The admin edits a section's Spanish

The admin's section form has fields for the Spanish heading, note and body. Saving it stores them, and editing the section shows them again. The form's labels stay in English (LC-4).

**Reason.** Content is edited at `/admin`, not in code, so the Spanish has to be too. (D-27)

Kind: functional. Proof: test, LC-16 in `test/contract/locale_contract_test.rb`.

### LC-17 Editable page copy falls back field by field

On a Spanish page, each editable copy field uses its Spanish default when its row is missing, and its English value when the saved Spanish is blank. English fallback declares `lang="en"` on its prose element; translated prose has no language override. English pages never use Spanish copy. Link labels follow the actual prose language.

**Reason.** Defaults keep production translated without a data step, and a saved blank requests the same readable, correctly pronounced fallback as sections. (D-30, D-31)

Kind: functional. Proof: test, LC-17 in `test/contract/locale_contract_test.rb`.

## Decisions

- D-30 and D-31, `docs/decisions/copy.md`: editable copy fallback and generated link labels (LC-17).

- D-8, `docs/decisions/locale.md`: the language control is a form that PATCHes, not a link (LC-6, LC-7, LC-10).
- D-9, `docs/decisions/locale.md`: back where the visitor was; home when that is unknown or foreign (LC-7, LC-8, LC-9).
- D-10, `docs/decisions/locale.md`: `Accept-Language` is read in the order sent (LC-2).
- D-11, `docs/decisions/locale.md`: each button names its language in that language (LC-10).
- D-27, `docs/decisions/locale.md`: Spanish sections are three columns that fall back field by field, and the interface chrome comes from the locale files (LC-12 to LC-16); editable prose is superseded by D-30.
