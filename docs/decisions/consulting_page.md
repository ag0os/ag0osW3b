# Decisions: the consulting page

Why the consulting page works the way it does, with the derivation behind each choice. The obligations are in `docs/contracts/consulting_page.md`.

### D-14. Seeded sections and a small page template

**Decision (proposed defaults).** Follow the other static pages: a PagesController
action selects visible, ordered consulting Sections, and the view reuses the
section partial. The page heading and dynamic LinkedIn contact sentence live in
the view, as other static page headers and contact links do. The meta description
is derived from the visible intro rather than a second copy.

**Derivation.** The admin already edits and toggles Sections; adding a second
content mechanism would make a small page harder to maintain. LinkedIn must
reflect SiteSetting changes rather than a profile URL captured during seeding.
The owner decided on 2026-10-13 that Consulting is reached from links in the
site's copy rather than the primary nav. This reverses only the nav half of
D5; the page stays as built.
Spanish translation is deferred (D6), so the page copy stays English
(superseded by D-29).
The English content declares its language even under Spanish chrome. Markdown's
existing curly apostrophe is kept rather than changing the renderer's Contract
for a single page. Obligations: CP-1 to CP-5.

### D-29. The consulting page is translated

**Decision.** The consulting sections get Spanish like every other seeded section, and the page's h1 and contact line move to the locale files. The container's `lang="en"` goes. Any part still shown in English is marked by the section partial instead (LC-14).

**Derivation.** On 2026-10-19 the owner chose to translate the page rather than keep it English under both locales, ending the deferral in D6. The footer CTA and the About and Contact copy already point Spanish readers to `/consulting` (SC-5), and an offer in another language reads as an afterthought. The English wording approved for CP-1 is unchanged. The Spanish is a draft of it, in the same order and with the same link, for the owner to correct in `/admin`. Obligation: CP-5.

D-30 and D-31 in `docs/decisions/copy.md` supersede the locale-file storage of the heading and contact sentence (2026-10-19), retaining their words as defaults.
