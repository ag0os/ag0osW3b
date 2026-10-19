---
component: seeded_copy
covers:
  - db/seeds.rb
  - db/seeds/sections_es.yml
  - db/migrate/20261019120100_fill_spanish_sections.rb
depends_on:
  - locale
tests:
  - test/contract/seeded_copy_contract_test.rb
---
Coverage: 7 obligations; 7 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: seeded copy

These obligations apply to the first-deploy copy loaded by `db/seeds.rb`, with tests that run the real seeds, and to the migration that brings its Spanish to a database seeded before there was any. The owner can still edit the wording in `/admin`; individual sentences are not pinned by this Contract.

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

The seeded About bio links to `/consulting`, and following that link reaches a public page successfully.

**Reason.** The invitation to consulting must lead to an offer the visitor can read without login.

Kind: functional. Proof: test, SC-3 in `test/contract/seeded_copy_contract_test.rb`.

### SC-5 The footer CTA, Contact intro and About bio link to consulting

The footer CTA in both locales, the Contact page's intro and the About bio each link to `/consulting`.

**Reason.** The owner decided on 2026-10-13 that the consulting page is reached from these entry points rather than the primary nav.

Kind: functional. Proof: test, the sixteen tests named SC-5 in `test/contract/seeded_copy_contract_test.rb` (fourteen footer tests, one per page in each locale, and one intro test per locale).

## Posts

### SC-6 The seeds plant no posts

The seeds plant no posts: loading them leaves the posts exactly as they were, so a freshly seeded site has none.

**Reason.** The owner does not want a template post on the live site; the first post is one the owner writes (settled 2026-10-14). (D-15)

Kind: functional. Proof: test, SC-6 in `test/contract/seeded_copy_contract_test.rb`.

## Spanish

### SC-7 Every seeded section has its Spanish

Every seeded section has Spanish for each field it has in English: a heading, a note, a body. A field blank in English is blank in Spanish too. The Spanish body links to the same addresses, in the same order, and marks the same number of phrases. On a seeded site, each page in Spanish shows its sections' Spanish, and nothing in them is marked as English.

**Reason.** The seeded copy is what the site says on its first deploy, and in Spanish it should read as Spanish from the start, not fall back to English (LC-14). The links and marks are what the English deliberately carries: the consulting link (SC-3, SC-5), the public repositories (SC-2), the phrases the presets draw. A translation that dropped one would quietly undo an obligation that the English passes. The wording is a draft for the owner to correct in `/admin`, so it is not pinned. (D-28)

Kind: functional. Proof: test, the two tests named SC-7 in `test/contract/seeded_copy_contract_test.rb`.

### SC-8 The migration fills blank Spanish and nothing else

`FillSpanishSections` copies each seeded section's Spanish into the section with the same key, one field at a time, and only into fields that are blank. It changes no English, no Spanish already written, and no section the copy does not name. It creates no section, it runs twice to the same result, and rolling it back changes nothing.

**Reason.** Seeds are not a deploy step, and running them again would overwrite whatever the owner has since edited in `/admin`. The migration runs with the deploy and only adds. (D-28)

Kind: functional. Proof: test, the three tests named SC-8 in `test/contract/seeded_copy_contract_test.rb`.

## Decisions

- D-15, `docs/decisions/writing.md`: Writing hides itself by asking whether anything is published (SC-6, with WR-1 to WR-3).
- D-28, `docs/decisions/seeded_copy.md`: the Spanish copy lives in one file, which the seeds and a fill-the-blanks migration both read (SC-7, SC-8).
