---
component: copy
covers:
  - app/models/site_setting.rb
  - app/controllers/admin/copies_controller.rb
  - app/controllers/admin/site_settings_controller.rb
  - app/helpers/copy_helper.rb
  - app/views/admin/copies/
  - app/views/admin/site_settings/
  - app/views/layouts/admin.html.erb
  - app/views/shared/_page_header.html.erb
  - config/routes.rb
depends_on:
  - locale
  - markdown_renderer
tests:
  - test/contract/copy_contract_test.rb
---
Coverage: 8 obligations; 8 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: editable page copy

The ten pairs of English and Spanish prose edited at Admin → Copy: hero tagline and note, Work and Writing intros, footer pitch, Consulting heading and contact sentence, and About, Work and Writing empty states. Sections, posts and interface labels retain their existing homes.

### CO-1 One bilingual copy editor

Admin → Copy offers all ten English/Spanish pairs, saves either language, and shows saved values on return. Its labels stay English.

**Reason.** The owner must refine page prose without a deploy or searching across editors. (D-30, D-31)

Kind: functional. Proof: test, CO-1 in `test/contract/copy_contract_test.rb`.

### CO-2 One editor per value

Copy alone edits this prose. Settings offers site title, email, URLs and theme, and neither update endpoint writes keys outside its own set.

**Reason.** Moving a field must not leave a second editor or let a copy submission overwrite unrelated settings. (D-30, D-31)

Kind: functional. Proof: test, CO-2 in `test/contract/copy_contract_test.rb`.

### CO-3 Defaults and existing hero overrides survive

Reworded 2026-10-22 by refine: copy SDLC; flagged for owner review.

Without stored copy rows, public copy retains the exact English and Spanish defaults from 4d307e9, except the tagline and its Spanish, changed by refine: copy SDLC (owner-approved 2026-10-22). Existing tagline, hero_note, tagline_es and hero_note_es rows retain their keys and values, except that a saved tagline or tagline_es still holding the old approved sentence takes the new one (SC-9). D-30 also applies to rows saved before this change: a pre-existing blank (including nil) or whitespace-only tagline_es or hero_note_es now shows English marked `lang="en"`, where it previously showed the Spanish default. Deploying requires no migration or seed run.

Clarified 2026-10-19 in fix round 1; the changed reading of pre-existing blank Spanish hero rows is flagged for owner acceptance.

**Reason.** Production already contains hero edits and has no rows for the new copy. (D-30, D-31)

Kind: functional. Proof: test, CO-3 in `test/contract/copy_contract_test.rb`.

### CO-4 Public copy follows the selected language

Every public copy placement reads its saved language value. Saved blank Spanish displays English on an element marked lang="en"; translated placements carry no redundant language attribute.

**Reason.** A partially translated site must remain readable and accurately pronounced. (D-30, D-31)

Kind: functional. Proof: test, CO-4 in `test/contract/copy_contract_test.rb`.

### CO-5 Link sentences keep their destinations

Each nonblank linked sentence contains exactly one of its designated placeholders, %{consulting_link} or %{linkedin_link}. Generated links retain their live destinations and existing behavior. Invalid submissions show an actionable error, keep submitted fields for correction and save no value.

**Reason.** Editing surrounding prose must not silently remove an invitation or partially save a form. (D-30, D-31)

Kind: functional. Proof: test, CO-5 in `test/contract/copy_contract_test.rb`.

### CO-6 Author text cannot inject HTML

Copy escapes author text except deliberately generated marks and links. Scripts, tags, attributes and literal entities cannot inject markup through prose, fields or metadata. Authors cannot supply link URLs through copy.

**Reason.** Database text must not inherit the trust previously given to developer-authored HTML translations. (D-30, D-31)

Kind: functional. Proof: test, CO-6 in `test/contract/copy_contract_test.rb`.

### CO-7 Marks retain their existing meaning

Mark-capable copy has multiline fields and renders ==marks== using the existing escaped plain-string mark semantics. Marks may surround generated links. Tagline metadata/feed and consulting titles are escaped plain text with marks removed. The margin note and consulting heading retain plain-text display.

**Reason.** Moving prose must preserve emphasis and link previews without changing its formatting language. (D-30, D-31)

Kind: functional. Proof: test, CO-7 in `test/contract/copy_contract_test.rb`.

### CO-8 A malformed submission is refused and writes nothing

A Copy or Settings submission whose `copy` or `settings` group is missing, is a single value or a list rather than a set of fields, holds none of its editor's own keys, or carries any of its own keys as a list or a set of fields is answered 400 Bad Request, never a server error, and saves no value, even when its other own fields are valid. Keys outside the editor's own set, nested or not, are still ignored (CO-2), and blank values still save.

Reworded 2026-10-21 by fix round 1 of this PR: a malformed own field refuses the whole submission.

**Reason.** Neither editor's form can produce such a request, so it is a mistake or a probe. Rejecting it whole keeps the endpoint from crashing and keeps a partial or stray write out of the settings. Close call on the membership test: the 400 is an HTTP answer any implementation can give, not Rails' parameter error.

Kind: functional. Proof: test, CO-8 in `test/contract/copy_contract_test.rb`.

## Decisions

- D-30, `docs/decisions/copy.md`: settings distinguish missing Spanish from saved blank Spanish (CO-1 to CO-4).
- D-31, `docs/decisions/copy.md`: escaped prose with one generated link placeholder (CO-5 to CO-7).
