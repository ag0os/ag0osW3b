---
component: home_page
covers:
  - app/controllers/home_controller.rb
  - app/views/home/
depends_on:
  - locale
  - markdown_renderer
tests:
  - test/contract/home_page_contract_test.rb
---
Coverage: 5 obligations; 5 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the home page

What the home page is once the shell is gone and before the copy replaces it (`PLAN.md` task 2 rewrites this Contract). `HomeController#show` renders it. HP-1 to HP-3 are what the page already shows besides the shell, pinned so that the deletion takes the shell and nothing else; HP-4 and HP-5 are the shell's removal.

## What it shows

### HP-1 The h1 is the tagline in the page's language

The page's one `<h1>` is the tagline in the page's language (`SiteSetting.localized("tagline")`), with its `==marks==` drawn as `<mark>`. The hero note (`hero_note`, `hero_note_es`), when there is one, sits in the hero's rail. The document title is the site title. Hero values are edited in Copy; missing Spanish uses its default and saved blank Spanish declares English fallback (CO-3, LC-17).

Reworded 2026-10-19 by Copy admin; flagged for owner review.

**Reason.** It is what the page already showed besides the shell, pinned so that the shell's deletion takes the shell and nothing else.

Kind: functional. Proof: test, the three tests named HP-1 in `test/contract/home_page_contract_test.rb`.

### HP-2 The visible home sections, in position order

Below the hero come the visible home sections in position order, each with its heading as an `<h2>`, its note, and its body rendered as Markdown. Position decides the order, not when a section was created: a home section created last with the lowest position comes first. Hidden sections and other pages' sections are absent.

**Reason.** It is what the page already showed besides the shell, pinned so that the shell's deletion takes the shell and nothing else.

Kind: functional. Proof: test, the two tests named HP-2 in `test/contract/home_page_contract_test.rb`.

### HP-3 The three most recently published posts

Then the three most recently published posts, newest first, each a link to its post with its publication date in a `<time>`, and a link to all writing. Drafts never appear. With nothing published there is no list and no heading for one.

**Reason.** It is what the page already showed besides the shell, pinned so that the shell's deletion takes the shell and nothing else.

Kind: functional. Proof: test, the three tests named HP-3 in `test/contract/home_page_contract_test.rb`.

## The shell's removal

### HP-4 No command line

The page has no command line: no form and no text field other than the footer's language control, no typed opening, and no script controller besides the header's theme controls.

**Reason.** The shell is replaced (`ASK.md` §11), and until the invitation arrives the page has to be complete for someone who never types.

Kind: functional. Proof: test, the two tests named HP-4 in `test/contract/home_page_contract_test.rb`.

### HP-5 Query parameters change nothing

Query parameters change nothing on the page: `/?line=whoami` renders what `/` renders and echoes nothing from the URL.

**Reason.** Links to the shell's old URLs are out in the world and should land on a working page. (D-12)

Kind: functional. Proof: test, HP-5 in `test/contract/home_page_contract_test.rb`.

## Decisions

- D-30 and D-31, `docs/decisions/copy.md`: editable prose and its unchanged defaults.

- D-12, `docs/decisions/home_page.md`: old shell URLs land on the plain home page (HP-5).
