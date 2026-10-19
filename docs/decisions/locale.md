# Decisions: the language

Why the language works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/locale.md`.

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

### D-27. Spanish sections are three columns that fall back field by field; the chrome comes only from the locale files

**Decision.** `sections` gets `heading_es`, `note_es` and `body_es`. `Section#localized` reads the column for the page's language, and falls back to the English column when that column is blank, one field at a time. A field shown in English on a Spanish page is marked `lang="en"`. Every other string on a public page comes from `config/locales/`, including the month names, so no `rails-i18n` gem is needed. Posts are not translated.

**Derivation.** `PLAN.md` chose the columns as the smallest change: a translations table pays for itself only with a third language. Settings already use the same pattern, a sibling with an `_es` suffix, read through `SiteSetting.localized`. Falling back one field at a time means a section can be translated in stages and stays readable throughout, and `lang` keeps assistive technology honest about which language each part is in. That is the reason CP-5 gave for marking the English consulting copy. Two checks hold the chrome: LC-12 compares pages with `en.yml`, and LC-13 reads the templates. The comparison alone misses a string that never made it into a locale file, and the scan alone misses English that reaches the page from a locale file whose Spanish twin is wrong. Posts stay as written (`ASK.md` §4.8). Obligations: LC-12 to LC-16.
