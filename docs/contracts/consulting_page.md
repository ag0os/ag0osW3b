---
component: consulting_page
covers:
  - app/views/pages/consulting.html.erb
  - app/controllers/pages_controller.rb
  - config/routes.rb
depends_on:
  - locale
  - markdown_renderer
  - seeded_copy
tests:
  - test/contract/consulting_page_contract_test.rb
---
Coverage: 5 obligations; 5 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the consulting page

The approved consulting brief is implemented at `/consulting`. CP-1 to CP-4 describe the page in English, and CP-5 describes it in each language. Navigation and seeded content are provisional defaults, pending the owner's decision. The owner settled the language on 2026-10-19: the page is translated like every other page.

## The copy

### CP-1 Approved copy and structure, public and unchanged

`/consulting` is public without login. Its one h1 defaults to “Agustín Calabrese: agentic development and AI-native systems”, editable in Copy. The intro, two numbered offers (including the four bullets and Troupe paragraph), and Background preserve the approved words and order, with no extra claims, placeholders, prices, formats, or em/en dashes. The intro leads with the systems built since 2025 and help for teams, then the 2024 change, because the owner approved that order (D3). Existing Markdown typography may curl the intro's apostrophe.

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** This is approved copy, not an invitation to rewrite it. (D-14)

Kind: functional. Proof: test, CP-1 in `test/contract/consulting_page_contract_test.rb`.

### CP-2 Only visible consulting sections, in position then id order

The copy is seeded as editable consulting Sections, rendered through the existing section partial: only visible consulting sections, in position then id order, guaranteed regardless of the database scan direction.

**Reason.** The owner manages static copy at `/admin`, and changing one page must not expose another page's content or hidden text. (D-14)

Kind: functional. Proof: test, CP-2 in `test/contract/consulting_page_contract_test.rb`.

### CP-3 Repository and contact links use the specified destinations

`github.com/ag0os/troupe` links to `https://github.com/ag0os/troupe`. After Background, the only contact line defaults to “Want to talk about your team? Get in touch on LinkedIn.”, with LinkedIn linked to the current `SiteSetting["linkedin_url"]`, opening in a new tab with `target="_blank"` and `rel="noopener"` as on Contact.

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** The public repository is the proof and the owner's configured profile is the contact destination, with the site's existing external-link behavior. (D-14)

Kind: functional. Proof: test, CP-3 in `test/contract/consulting_page_contract_test.rb`.

## The head

### CP-4 Title and descriptions are escaped plain text

The document and Open Graph title use the current editable heading, unmarked, followed by the site title; description and Open Graph description use the visible consulting intro, with marks removed and whitespace collapsed, falling back to the layout's description when absent. Text outputs are escaped, never HTML.

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** A shared link must identify this page and edits must not inject markup into the head. (D-14)

Kind: functional. Proof: test, the two tests named CP-4 in `test/contract/consulting_page_contract_test.rb`.

## Language and navigation

### CP-5 Copy in the page's language, and no nav link

The page's copy is in the page's language, with the normal locale-specific chrome, language control and theme controls, and no link to `/consulting` in the primary nav. In Spanish, the h1, the document title, the description, the contact line and each section are in Spanish: the sections from their Spanish fields (LC-14), and the heading and contact sentence from localized copy settings, with unchanged defaults (CO-3, LC-17). Copy that shows in English on a Spanish page because its Spanish is blank declares `lang="en"`. When everything is translated, nothing in the page declares a language of its own.

Reworded 2026-10-19 by the Spanish copy PR: the copy was English under both locales, in a container that declared `lang="en"`.

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** The owner decided on 2026-10-13 that the page is reached from links in the site's copy rather than the primary nav (reversing the nav half of D5). On 2026-10-19 the owner decided to translate it, ending the deferral in D6, so a Spanish reader is offered consulting in Spanish. Assistive technology still needs the prose's actual language wherever it falls back. (D-14, D-29)

Kind: functional. Proof: test, the two tests named CP-5 in `test/contract/consulting_page_contract_test.rb`.

## Decisions

- D-30 and D-31, `docs/decisions/copy.md`: editable prose and its unchanged defaults.

- D-14, `docs/decisions/consulting_page.md`: seeded sections and a small page template (CP-1 to CP-5).
- D-29, `docs/decisions/consulting_page.md`: the consulting page is translated (CP-5).
