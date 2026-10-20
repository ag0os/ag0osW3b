# Decisions: the language

Why the language works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/locale.md`.

### D-8. The language control is a form that PATCHes, not a link

**Decision.** Each footer button is a `button_to`-style form that posts to `/locale` with `_method=patch`; `LocalesController#update` sets the cookie and answers `303 See Other`.

**Derivation.** Choosing a language changes stored state, so it is not a GET. A link such as `/locale?l=es` would also be followed by things that are not the visitor: Turbo prefetches a link on hover, and crawlers follow every link, so hovering over "Español" could switch the site. A form needs no JavaScript, which `ASK.md` §4.9 requires of the whole surface. The redirect is `303` rather than Rails' default `302` because the follow-up must be a GET whatever method the browser sent, and `303` is the status that says so; Turbo expects it after a form submission. Obligations: LC-6, LC-7, LC-10.

### D-9. Back where the visitor was; home when that is unknown or foreign

**Decision.** The redirect goes to the `Referer` when it is on this host, else to the home page (`redirect_back_or_to root_path`). An unknown code changes nothing and redirects the same way.

**Derivation.** The visitor pressed the button to read the page they were on in another language, so that page is the destination. The `Referer` is supplied by the request, so following it to another host would make `/locale` an open redirect; Rails refuses other hosts in `redirect_back_or_to` and falls back. An unknown code can only come from a stale page or a hand-written request; an error page punishes the first and tells the second nothing, so the request is treated as a no-op. Only the exact codes the buttons send are accepted: `ES` is not one of them, and accepting it would mean the control normalises codes that nothing it renders ever sends. Obligations: LC-7, LC-8, LC-9.

Mechanism superseded by D-35 (2026-10-20)

### D-10. `Accept-Language` is read in the order sent

**Decision.** The first entry whose language is a site language wins; `q` weights are not used to re-sort. This is the behaviour the shell shipped, pinned as it is.

**Derivation.** Browsers emit entries already in descending preference, so re-sorting changes nothing for a real browser and only matters for a hand-written header. With two site languages the first match is also the only decision there is to make. Obligation: LC-2.

### D-11. Each button names its language in that language

**Decision.** The buttons read "English" and "Español" on every page, each with `lang`, and the current one is marked with `aria-pressed`.

**Derivation.** The control exists for the visitor who landed in the wrong language (`ASK.md` §4.8: Spanish browsers already get Spanish), so the label they need is the one in the language they read, not a translation into the one they cannot. `lang` on the button lets a screen reader switch voice for the one word. The pressed state is the mode toggle's pattern: one stable name per button plus a state, so the current language is stated in text to assistive technology and never by hue alone. Obligations: LC-10.

### D-27. Spanish sections are three columns that fall back field by field; the chrome comes only from the locale files

**Decision.** `sections` gets `heading_es`, `note_es` and `body_es`. `Section#localized` reads the column for the page's language, and falls back to the English column when that column is blank, one field at a time. A field shown in English on a Spanish page is marked `lang="en"`. Every other string on a public page comes from `config/locales/`, including the month names, so no `rails-i18n` gem is needed. Posts are not translated.

**Derivation.** `PLAN.md` chose the columns as the smallest change: a translations table pays for itself only with a third language. Settings already use the same pattern, a sibling with an `_es` suffix, read through `SiteSetting.localized`. Falling back one field at a time means a section can be translated in stages and stays readable throughout, and `lang` keeps assistive technology honest about which language each part is in. That is the reason CP-5 gave for marking the English consulting copy. Two checks hold the chrome: LC-12 compares pages with `en.yml`, and LC-13 reads the templates. The comparison alone misses a string that never made it into a locale file, and the scan alone misses English that reaches the page from a locale file whose Spanish twin is wrong. Posts stay as written (`ASK.md` §4.8). Obligations: LC-12 to LC-16.

Editable page prose is superseded by D-30 and D-31 in `docs/decisions/copy.md` (2026-10-19); interface translations remain in the locale files.

### D-33. Each language has a public path; bare addresses negotiate in place

**Decision.** Constrain an optional public locale scope from available_locales. Only request.path_parameters selects the path language; then the cookie, browser order and English decide. Public URL defaults use path_params so unused locale values never leak into admin, auth, health or control queries. Bare HTML and Atom responses stay in place with private caching and merged Accept-Language Vary; prefixed responses stay private without adding that field. Feed alternate, self and ids are explicit, preserving the existing English id.

**Derivation.** The owner chose scheme B on 2026-10-20. English-unprefixed would still negotiate Spanish, leaving English without a stable address. A redirect from bare would move shared addresses by a guess; a single Spanish landing page would leave the rest monolingual. Rails’ optional scope and path_params handle these requirements without a new routing abstraction. URL defaults are cached per request; alternate generation uses explicit locale arguments rather than changing I18n.locale. A future shared cache must honour private; Vary alone cannot express cookie or future country choices. Promises apply to fresh responses, not a stale snapshot in another browser tab.

Obligations: LC-1 to LC-3, LC-7 to LC-9, LC-11, LC-18, LC-19, LC-21, LC-23, WR-4, WR-5.

### D-34. Metadata names the representation; links localise at rendering

**Decision.** Each public HTML representation has its rendered-language canonical and og:url, reciprocal en/es alternates and bare x-default, plus rendered Open Graph locale. Localise recognised single-slash public links in section/post rendered Markdown, including Atom content, preserving raw query and fragment and leaving storage unchanged. The owner settled that every post is English on 2026-10-20; mark its title/body and Atom title/summary/content as English only within Spanish representations. Admin Copy offers explicit language previews.

**Derivation.** Bare URLs are selectors; language URLs are stable shareable versions. Hreflang supports translated templates even where posts are unchanged. A sitemap adds no separate requirement beyond the equivalent head links. Rewriting seeded bodies by migration would bind stored content to routing and overwrite owner edits. On 2026-10-20 the owner confirmed preservation of raw query/fragment, localisation of already-prefixed authored links and Atom entry content, and metadata/Copy preview evidence under LC-18/LC-20/LC-21. Text fallback language does not change the rendered language that links follow. Third-language Copy storage is excluded.

Obligations: LC-18, LC-20, LC-21, LC-22, SC-3, SC-5, SC-7.

### D-35. The PATCH form redirects to a safely rebuilt counterpart

**Decision.** Keep the PATCH forms and permanent cookie of D-8. Validate a choice exactly, check url_from and explicit URI constraints, recognise only a public GET route, and rebuild a local path from recognised parameters. Append the raw query as text; redirect 303 using Rails’ default refusal of open redirects. Root-relative public referrers work. Missing, foreign, malformed, protocol-relative, user-info-bearing, non-http/https, wrong-port, unknown and non-public referrers fall back to chosen-language home. Invalid choices write no cookie and preserve a safe public original path locale/query or fall back to bare home. A recognised nonexistent post slug still leads to its normal 404.

**Derivation.** D-8’s prefetch/crawler reasons for a form survive. Recognition alone accepts non-public routes and foreign hosts, so it cannot establish the boundary. Query keys merged as URL options can configure host/protocol; keeping raw query avoids that. Correction to design 1.3, accepted by the owner on 2026-10-20: Rails 8.1.3.1 url_from checks the host, not the entire stated origin policy. Explicitly reject protocol-relative spelling and user-info, require http or https and the request’s port on absolute referrers, before recognition. Root-relative referrers are allowed. Both http and https are allowed on the request’s port; scheme equality is not imposed. The installed source and https://api.rubyonrails.org/v8.1.3/classes/ActionController/Redirecting.html establish the API limitation.

**Further correction, owner ruling 2026-10-20.** Design 1.3’s explicit `allow_other_host: false` is omitted. With `load_defaults 8.1`, this app’s `ActionController::Base.action_on_open_redirect` is `:raise`; LC-8 pins that policy so a configuration change weakening the independent guard fails the suite. The already-local rebuilt destination makes the explicit option observationally redundant. Rails convention over configuration retains the guard without an equivalent-survivor acceptance. The original permanent-cookie assignment is retained after validation to preserve baseline comparison of its SameSite defaults. Rebuilding uses the native view `url_for`, whose `only_path` default is true when no host option is supplied; trusted route parameters carry no host, and query keys are never merged into those options. The local-path tests pin that output. This removes redundant configuration rather than accepting equivalent mutants (https://api.rubyonrails.org/v8.1.3/classes/ActionView/RoutingUrlFor.html).

Obligations: LC-7, LC-8, LC-9, LC-11.
