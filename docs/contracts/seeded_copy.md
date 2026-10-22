---
component: seeded_copy
covers:
  - db/seeds.rb
  - db/seeds/sections_es.yml
  - db/migrate/20261019120100_fill_spanish_sections.rb
  - db/migrate/20261019120100_fill_spanish_sections.yml
  - db/migrate/20261022120000_swap_sdlc_copy.rb
depends_on:
  - locale
tests:
  - test/contract/seeded_copy_contract_test.rb
---
Coverage: 8 obligations; 8 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: seeded copy

These obligations apply to the first-deploy copy loaded by `db/seeds.rb`, with tests that run the real seeds, to the migration that brings its Spanish to a database seeded before there was any, and to the migration that carries the owner's approved fragment changes to the live copy. The owner can still edit the wording in `/admin`; individual sentences are not pinned by this Contract.

## Links

### SC-1 No Claude Forge

The seeded public site neither names Claude Forge nor links to `ag0os/claude-forge`.

**Reason.** The retired toolkit must not send visitors to superseded proof.

Kind: functional. Proof: test, SC-1 in `test/contract/seeded_copy_contract_test.rb`.

### SC-2 Work links Troupe to its public repository

The seeded Work open-source section links Troupe to `https://github.com/ag0os/troupe`.

**Reason.** Visitors evaluating the current toolkit need its public repository.

Kind: functional. Proof: test, SC-2 in `test/contract/seeded_copy_contract_test.rb`.

### SC-3 About bio links to a public consulting page

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

The rendered seeded About bio links to the consulting address of the rendered language (`/en/consulting` or `/es/consulting`), and following that link reaches a public page successfully.

**Reason.** The invitation to consulting must lead to an offer the visitor can read without login.

Kind: functional. Proof: test, SC-3 in `test/contract/seeded_copy_contract_test.rb`.

### SC-5 The footer CTA, Contact intro and About bio link to consulting

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

The default footer CTA in both locales (editable in Copy with its consulting link retained), the Contact page's intro and the About bio each render a link to the consulting address of the rendered language (`/en/consulting` or `/es/consulting`).

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** The owner decided on 2026-10-13 that the consulting page is reached from these entry points rather than the primary nav.

Kind: functional. Proof: test, the sixteen tests named SC-5 in `test/contract/seeded_copy_contract_test.rb` (fourteen footer tests, one per page in each locale, and one intro test per locale).

## Posts

### SC-6 The seeds plant no posts

The seeds plant no posts: loading them leaves the posts exactly as they were, so a freshly seeded site has none.

**Reason.** The owner does not want a template post on the live site; the first post is one the owner writes (settled 2026-10-14). (D-15)

Kind: functional. Proof: test, SC-6 in `test/contract/seeded_copy_contract_test.rb`.

## Spanish

### SC-7 Every seeded section has its Spanish

Reworded 2026-10-20 by refine: locale URLs; flagged for owner review.

Every seeded section has Spanish for each field it has in English: a heading, a note, a body. A field blank in English is blank in Spanish too. The stored Spanish body links to the same addresses, in the same order, and marks the same number of phrases. On a seeded site, each page in Spanish shows its sections' Spanish, and nothing in them is marked as English. Rendering localises recognised public links to the page’s language without changing the stored bodies (D-34).

**Reason.** The seeded copy is what the site says on its first deploy, and in Spanish it should read as Spanish from the start, not fall back to English (LC-14). The links and marks are what the English deliberately carries: the consulting link (SC-3, SC-5), the public repositories (SC-2), the phrases the presets draw. A translation that dropped one would quietly undo an obligation that the English passes. The wording is a draft for the owner to correct in `/admin`, so it is not pinned. (D-28)

Kind: functional. Proof: test, the three tests named SC-7 in `test/contract/seeded_copy_contract_test.rb`.

### SC-8 The migration fills blank Spanish and nothing else

Reworded 2026-10-22 by refine: copy SDLC; flagged for owner review.

`FillSpanishSections` copies each seeded section's Spanish, as seeded on 2026-10-19 and frozen beside the migration, into the section with the same key, one field at a time, and only into fields that are blank. It changes no English, no Spanish already written, and no section the copy does not name. It creates no section, it runs twice to the same result, and rolling it back changes nothing.

**Reason.** Seeds are not a deploy step, and running them again would overwrite whatever the owner has since edited in `/admin`. The migration runs with the deploy and only adds. (D-28)

Kind: functional. Proof: test, the three tests named SC-8 in `test/contract/seeded_copy_contract_test.rb`.

## Approved changes

### SC-9 The SDLC copy migration swaps the approved fragments and nothing else

`SwapSdlcCopy` replaces each approved old fragment from 2026-10-22 with its new wording, in exactly these stored fields: the `tagline` and `tagline_es` settings, the English and Spanish bodies of `home_what_i_do`, and the English bodies of `contact_intro` and `about_bio`. In a named field it replaces every exact occurrence of the approved old fragment and keeps the content around it; a field without the exact fragment is left alone. It changes no other field (the row's timestamps included), setting or section, creates no row (a tagline never saved in the admin stays unsaved), runs twice to the same result, and rolling it back changes nothing. On a database holding the old fragments, each page then shows the new wording in both languages.

**Reason.** Seeds are not a deploy step, and running them again would overwrite whatever the owner has since edited in `/admin` (SC-8). Requiring the exact old fragment leaves alone any field where the owner removed or changed it, and everything else as the owner left it; a rewrite that kept the exact fragment still gets the swap. (D-36)

Kind: functional. Proof: test, the five tests named SC-9 in `test/contract/seeded_copy_contract_test.rb`.

## Decisions

- D-34, `docs/decisions/locale.md`: render-time public link localisation (SC-3, SC-5, SC-7).

- D-30 and D-31, `docs/decisions/copy.md`: editable prose and its unchanged defaults.

- D-15, `docs/decisions/writing.md`: Writing hides itself by asking whether anything is published (SC-6, with WR-1 to WR-3).
- D-28, `docs/decisions/seeded_copy.md`: the Spanish copy lives in one file, which the seeds and a fill-the-blanks migration both read (SC-7, SC-8).
- D-36, `docs/decisions/seeded_copy.md`: approved copy changes reach the live site through a migration that swaps only the approved old fragments; the fill migration's input is frozen (SC-8, SC-9).
