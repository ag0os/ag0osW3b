# Contracts

One file per component, `docs/contracts/<component>.md`. A component is the
unit you would delete and rebuild as one thing: the Markdown renderer, the
language, the home page. `<component>` is a lowercase slug with underscores,
the stem of its test file in `test/contract/` (`markdown_renderer` for
`markdown_renderer_contract_test.rb`). Until a component's file exists, its
Contract is its `## Contract: ...` section in `PRODUCT.md`; `AGENTS.md` says
when it moves.

## The file

```markdown
---
component: markdown_renderer
covers:
  - app/services/markdown_renderer.rb
  - app/helpers/markdown_helper.rb
depends_on: []
tests:
  - test/contract/markdown_renderer_contract_test.rb
---
Coverage: 21 obligations; 21 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the Markdown renderer

<a short paragraph: what the component is>

## Safety

### MR-5 a link or image with an unsafe URL loses its URL and keeps its text

<the statement, as many sentences as it needs>

**Reason.** <why it must hold, as many sentences as it needs> (D-6)

Kind: functional. Proof: test, the five tests named MR-5 in `test/contract/markdown_renderer_contract_test.rb`.

## Decisions

- D-6, `docs/decisions/markdown_renderer.md`: raw HTML is omitted, and unsafe URLs are emptied (MR-4, MR-5).
```

**Front matter.** These four fields and no others.

- `component`: the slug, equal to the file name.
- `covers`: the paths the Contract is about, from the repo root: directories,
  files or globs. A directory named by two files is a finding; a shared file
  such as `config/routes.rb` may be named by several.
- `depends_on`: the slugs of components this one calls or reads. `[]` when none.
- `tests`: the files or directories holding its contract tests.

**The coverage line** is the first line of the body. Keep it true by hand in
every PR that touches the file. It counts the obligations, then how each is
proved: by test, by PR evidence, mixed (part each), or unproved (a statement
with no proof yet, allowed and counted, never hidden). Its last sentence says
whether the suite runs against this implementation or against any
implementation behind a named interface.

**Obligations.** One `###` heading each: the id, then a short name. Under it:

- the statement, what must hold;
- a **Reason.** paragraph, always, with a decision pointer such as `(D-6)`
  where one exists;
- one line, `Kind: functional.` or `Kind: non-functional.`, then `Proof:`
  `test` with the file and the test's id, `pr-evidence` with the PR or the
  record's path, or `none`. A non-functional obligation names its budget,
  where it is measured and how.

Ids are `<PREFIX>-<n>` and a number is never reused. `##` headings may group
obligations ("Safety", "Tables").

**The membership test.** Would reimplementing the component in another
language invalidate the assertion? If yes, it tests the implementation and
stays out of the Contract. Record a close call in the reason.

**Changes.**

- A retired obligation keeps its heading, with `Retired <date>, <why>.` under
  it and no proof.
- A reworded obligation keeps its id and gets a dated line under it:
  `Reworded <date> by <the PR>.` Flag the change in the PR for the owner.

**Decisions by pointer.** The Contract never holds a derivation. It points to
one, in the reason, and lists each pointer in a closing `## Decisions` section
with its id, path and title, and the obligations it bears on. Decisions live in
`docs/decisions/<component>.md`, or in `DECISIONS.md` until the component's
decisions have moved.

**What else it may hold.** The head paragraph, the grouping headings, and the
dated lines. Nothing that belongs in a plan (delivery order, tasks) or a guide
(how to run it).
