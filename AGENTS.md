# AGENTS.md

Guidance for AI agents (and humans) working in this repo.

## What this is

`ag0osW3b` is Agustin Calabrese's personal website: a small, **vanilla Rails 8.1**
app with a Markdown blog and a login-only admin for managing content. Content
lives in the database and is edited through `/admin`.

## Golden rules

- **Stay vanilla.** Prefer built-in Rails over gems and frameworks. This app
  deliberately uses the Rails defaults: Propshaft, import maps, Hotwire,
  SQLite + Solid, and the built-in authentication generator.
- **No Tailwind. No Node build step.** Styling is **plain CSS** with
  custom-property design tokens. Do not add Tailwind, PostCSS,
  `cssbundling`/`jsbundling`, or any Node toolchain.
- **Keep it small.** This is a personal site, not an enterprise app. Favor the
  simplest thing that works; don't introduce service layers, gems, or
  abstractions it doesn't need.
- **Match the surrounding code** you're editing (naming, structure, thin
  controllers, ERB + partials).
- **Content is public.** Copy in seeds and views is public-facing. Never add
  secrets, credentials, or private personal data. `config/master.key` and
  `storage/` are gitignored — keep it that way.

## Stack

- Ruby 4.0.5 · Rails 8.1 (see `.ruby-version`)
- Propshaft · import maps · Hotwire (Turbo + Stimulus)
- Plain CSS design system in `app/assets/stylesheets/`: `themes.css` (tokens +
  presets), `application.css` (reset, base, layout), `components.css`,
  `admin.css`
- SQLite + Solid Queue/Cache/Cable
- `commonmarker` + `rouge` for Markdown posts

## Commands

```bash
bin/setup             # install gems + prepare the database
bin/rails db:seed     # admin user + starter content (ADMIN_EMAIL / ADMIN_PASSWORD; production requires ADMIN_PASSWORD)
bin/rails server      # http://localhost:3000  (admin at /admin)
bin/rails test        # Minitest suite — keep it green
bin/rubocop           # rails-omakase style — keep it clean
bin/ci                # the full check, exactly what GitHub runs; run it before saying done
```

## Architecture

### Content model (all editable at `/admin`)

- **`Section`** — static content blocks (Markdown `body`), grouped by `page`
  (`home`/`about`/`work`/`contact`), ordered by `position`, shown when
  `visible`. An optional `note` puts a short line in the page margin. Public pages render `Section.for_page(x).visible.ordered`.
- **`Post`** — Markdown blog posts, `draft`/`published` (enum), public at
  `/writing/:slug`. `published_at` is set automatically on publish.
- **`SiteSetting`** — key/value site-wide settings and bilingual page prose.
  Ordinary settings read via `SiteSetting["key"]`, with blank values falling
  back to `SiteSetting::DEFAULTS`. Copy keys read through `SiteSetting.localized`:
  a missing Spanish row uses its Spanish default; a saved blank Spanish row
  uses English, including rows saved before this change (D-30 in
  `docs/decisions/copy.md`). The Copy helpers mark English fallback `lang="en"`.

### The front door

Read **`ASK.md`** for the front door being built. The home page currently
renders its tagline, visible sections and recent writing.

**Two languages.** Public pages and feeds have fixed `/en` and `/es` addresses;
bare addresses negotiate in place. `SiteController` picks the locale from the
path segment, then the `locale` cookie set by the footer’s language buttons,
then `Accept-Language`, then English. Query parameters never choose the page’s
language. `LocalesController#update` saves a valid choice and redirects to the
same public page at its chosen-language address, after checking the referrer.
`LocalizedLinksHelper` localises public links in rendered Markdown without
changing stored prose. The chrome strings live in `config/locales/en.yml`
and `es.yml` under one matching tree. Localised settings are sibling keys with
an `_es` suffix read through `SiteSetting.localized`. Sections have Spanish
columns (`heading_es`, `note_es`, `body_es`) read through `Section#localized`,
which falls back to the English field when the Spanish is blank; the section
partial marks that English `lang="en"`. Public templates write no words of
their own: interface strings go through `t()`, page prose comes from Admin →
Copy through the copy helpers, and sections/posts supply their own content
(LC-13 guards these sources). Dates go through `l()`. Posts stay as written.
The admin stays English, with fields for each section's Spanish. Seeded Spanish lives in
`db/seeds/sections_es.yml`.

### Public vs admin

- Public controllers inherit **`SiteController`** (`allow_unauthenticated_access`,
  and the locale switch above).
  The `Authentication` concern makes the app login-required by default, so public
  controllers opt out there.
- Admin controllers live under `Admin::` and inherit **`Admin::BaseController`**
  (login-only, `layout "admin"`).
- Auth is the **Rails 8 built-in** generator: `User` / `Session` / `Current` +
  `app/controllers/concerns/authentication.rb`. Single admin user (from seeds).
  No Devise.

### Markdown

`MarkdownRenderer` (`app/services/markdown_renderer.rb`) renders Markdown →
sanitized HTML. It **disables Commonmarker's built-in (inline-style) highlighter**
and applies **Rouge** with CSS classes instead, so code blocks are themeable via
plain CSS (see the `.highlight .*` rules in `application.css`). Use the
`markdown(text)` helper in views.

It also turns **`==phrase==` into `<mark>`**, the site's emphasis primitive, which
every preset draws with its own instrument (a marker swipe, a strip of tape, a
ruled red line, a filled cell). It is applied to the rendered tree, so `==this==`
inside code stays literal. For plain strings use the `marked(text)` helper, and
`unmarked(text)` for anywhere that takes text rather than markup: `<title>`, meta
descriptions, the feed.

Its Contract, and how to change it, is under "The Contract and the checks" below.

### Design system

Read **`DESIGN.md`** (visual contract) and **`PRODUCT.md`** (strategy, audience,
anti-references) before doing design work. The short version:

**Two independent axes on `<html>`:**

| Attribute | Values | Meaning |
|---|---|---|
| `data-theme` | `workshop` `console` `spec` `terminal` | the design identity |
| `data-mode` | `light` `dark` (absent = follow OS) | light/dark |

Four presets times two modes is eight surfaces, and all eight ship. `workshop`
is the default; the active default comes from `SiteSetting.theme_preset` and is
editable at `/admin/settings`.

**The contract.** `themes.css` defines every preset as paired `--l-*` / `--d-*`
values plus type and shape tokens; one MODE RESOLUTION block at the bottom maps
those onto the semantic role names. Components consume **only** semantic roles
(`--bg`, `--text`, `--accent`, `--radius`, `--font-body`, ...). Two hard rules,
both enforced by tests:

- No hex, `rgb()`, or `hsl()` literal in any stylesheet. Color is authored in
  OKLCH in `themes.css` or it is wrong in seven of the eight surfaces.
- No `[data-theme="..."]` selector outside `themes.css`. If a component needs to
  differ per preset, the difference belongs in the token contract.

Presets vary color, type, shape, **rhythm, section grammar, ground and motion**.
They never vary **markup**, which is what keeps a component a single
implementation. The presentation tokens that carry that:

| Token | Decides |
|---|---|
| `--density` | multiplier on the whole spacing scale |
| `--rule-width` / `--rule-style` | how sections are separated |
| `--heading-marker` | what precedes a heading (substituted into `content:`) |
| `--texture` | the page's CSS-generated ground |
| `--ease` / `--dur` / `--dur-enter` / `--stagger` | how the preset moves |
| `--mark-image` / `--mark-radius` | what a marked phrase is drawn with |
| `--font-hand` / `--note-*` | how a margin note is written |
| `--ink-stroke`, `--lamp-*`, `--dimension-*`, `--endmark-*` | the preset's one delight |

**One delight per preset.** Each of those slots is inert in `:root` and answered
by exactly one preset (workshop's drawn underline, console's tally lamp, spec's
dimension line, terminal's returning prompt), so the mechanism ships everywhere
and the performance belongs to one. `stylesheet_test.rb` fails the build if a
slot is answered twice, a preset answers two, or a slot loses its inert default.
See DESIGN.md for what each names.

`test/design/stylesheet_test.rb` fails the build if a preset omits any identity
token, or if two presets share a design fingerprint.

**Fonts** are self-hosted and open licensed. Run `bin/fetch-fonts` once and
commit the `.woff2` files; see `app/assets/fonts/README.md`. The site works
without them, since every `--font-*` token carries a system-stack fallback and
`assets:precompile` leaves unresolvable `url()` references alone rather than
raising.

**Adding a preset:** copy a `[data-theme="..."]` block in `themes.css`, fill in
all 14 `--l-`/`--d-` pairs plus type and shape tokens, add the name to
`SiteSetting::PRESETS` and `PRESET_LABELS`, run `bin/rails test`. No component
changes needed.

**Cascade layers.** `themes.css` declares
`@layer tokens, base, layout, components, utilities;` once, and every rule lives
in a layer. New component CSS appends to `@layer components` and cannot
accidentally outrank base styles.

**Switching.** `theme_controller.js` (Stimulus) writes both attributes and
persists to `localStorage`; an inline script in the layouts applies them before
first paint. The server never renders `data-mode`, so with JavaScript off the OS
preference decides via a media query. The switcher itself is hidden until that
script adds a `js` class to `<html>`.

**Careful:** a `*/` inside CSS comment prose closes the comment early and voids
the rest of the file. Every route still returns 200 and the site renders as
unstyled HTML. `test/design/stylesheet_test.rb` catches it.

## Conventions & gotchas

- **`Post#to_param` is the slug.** Public routes use `/writing/:slug`; admin post
  routes therefore also carry the slug as `:id`, and `Admin::PostsController#set_post`
  looks up with `find_by!(slug:)`. **`Section` uses numeric ids** (no `to_param`
  override).
- **`allow_browser versions: :modern`** is set in `ApplicationController` — UA-less
  or non-modern clients get 406. Send a modern `User-Agent` when scripting requests.
- DB-backed content: adding a `Section` in the admin makes it appear automatically
  on its page (no view edits needed).
- Deployment is handled outside this repo. Don't add Dockerfiles, Kamal, or CI
  deploy configs unless asked. In production, `storage/` must be on a persistent
  disk (SQLite + Solid databases live there).

## The Contract and the checks

Each component's obligations are its Contract: an id, a statement, a reason,
and its proof (a test in `test/contract/` named by the id, or recorded PR
evidence). **A PR that adds or changes behavior updates the component's
Contract in the same PR.** Decisions and their derivations live in
`docs/decisions/` once moved, and in `DECISIONS.md` until then; the Contract
points to them and never repeats them.

**Where a Contract lives.** Contracts are moving to
`docs/contracts/<component>.md`, whose format is in `docs/contracts/README.md`.
Until a component's file exists, its Contract is its section in `PRODUCT.md`,
written as bullets (`- **MR-1** statement *Because* reason`), and its decisions
are in `DECISIONS.md`. A component with neither has no Contract; claim no
coverage for it.

| `PRODUCT.md` section | Ids | Tests in `test/contract/` | File when moved |
|---|---|---|---|
| Contract: the Markdown renderer | MR | `markdown_renderer_contract_test.rb` | `markdown_renderer.md` |
| Contract: the language | LC | `locale_contract_test.rb` | `locale.md` |
| Contract: editable page copy | CO | `copy_contract_test.rb` | `copy.md` |
| Contract: the home page | HP | `home_page_contract_test.rb` | `home_page.md` |
| Contract: the post page | PP | `post_page_contract_test.rb` | `post_page.md` |
| Contract: retiring the shell's settings | DM | `remove_shell_settings_contract_test.rb` | `remove_shell_settings.md` |
| Contract: the consulting page | CP | `consulting_page_contract_test.rb` | `consulting_page.md` |
| Contract: seeded copy | SC | `seeded_copy_contract_test.rb` | `seeded_copy.md` |
| Contract: writing | WR | `writing_contract_test.rb` | `writing.md` |
| Contract: the production deploy | PD | `production_contract_test.rb`, and PD-5 in `canonical_host_contract_test.rb` | `production.md` |
| Contract: continuous integration | CI | `ci_contract_test.rb` | `ci.md` |

**Moving on touch.** A PR that touches a component moves its section into
`docs/contracts/<component>.md`, in the README's form, in that same PR:

- ids unchanged, and no change to any obligation's meaning;
- `PRODUCT.md` keeps a one-line pointer to the new file;
- the component's decisions (the ones whose `Obligations:` line names its ids)
  move from `DECISIONS.md` to `docs/decisions/<component>.md` the same way,
  with `DECISIONS.md` keeping a pointer.

**A bug live in production** goes into the Contract first:

1. Add the missing obligation to the component's Contract, with the next
   unused number for its prefix.
2. Write its test, named by the id (`test "MR-22 ..."`), in the component's
   file in `test/contract/`, and run it red
   against the unfixed code. Say in the PR how it was shown red.
3. Fix the code.
4. Where mutant covers the code (the subjects in `config/mutant.yml`), run
   `bundle exec mutant run 'Subject#method'` on the fixed code and check that
   no survivor undoes the fix; the red run in step 2 is what shows the test
   catches the bug. The run exits nonzero while the baseline's own survivors
   live.
5. Run `bin/ci`, as under "The checks" below.
6. Label the PR `fix:` and name the id.

Everything else is `refine:`.

**The checks.** Before you say done, run `bin/ci` (fetch first: locally it
compares with `origin/main`, or `$CI_BASE`). GitHub runs exactly it on every
pull request. A check that couldn't run is a gap to name, never a pass. The
steps are in `config/ci.rb`, and what a green run means is `PRODUCT.md`
"Contract: continuous integration" (CI-1 to CI-9, decisions D-20 to D-25):

- **Mutation** is a gate. It runs every subject in `config/mutant.yml` twice:
  on the change, and on its merge base. The base is exported from git and run
  with the change's harness, bundle and seed. `bin/mutant-floor` runs the gate
  on its own, in about 80 seconds locally. It fails on a survivor the base
  doesn't have, counted per subject and changed lines.
  - A test that kills a known survivor just passes.
  - A method renamed within its own class passes (the class runs a new
    subject, one for each renamed method), and survivors carry across a
    rename or a move into a concern. Merging two methods into one drops a
    subject, so it needs an entry as below.
  - A method the change no longer defines by that name, and didn't rename in
    its own class, fails as removed or renamed out of mutation's reach: a
    deletion, or an extraction under a new name. If you deleted it, add an
    entry as below.
  - A method that is still defined somewhere under `app/`, `lib/` or
    `config/`, but that no subject runs any more, fails. The step names where
    the method now lives. To fix it, select that place in `config/mutant.yml`
    (an owned file) and give its tests a `cover` line for it.
  - A cosmetic edit to a line that has a survivor (renaming a block variable)
    makes that survivor new. Kill it with a test, or accept it as below.

  These need an entry with a reason in the owned `test/mutant/accepted.yml`:
  - a new survivor no test can kill (`equivalents`);
  - a method that is no longer mutated, because `config/mutant.yml` stopped
    selecting it, it left the selection, or it was deleted (`config`, naming
    it in `subjects`);
  - a change to `config/mutant.yml` outside its subjects and ignores
    (`change: config`);
  - any change to `test/mutant/boot.rb` or `test/mutant/hooks.rb`
    (`change: harness`).

  Such an entry takes the PR outside G1, so say why in the PR. The step
  prints what each entry accepted, with its reason. The file is append-only.

  If the step prints GAP AT THE BASE, the base itself won't run, and your
  change can't fix that, so report it. When the gap says the base can't run
  under this change's bundle or harness, split the change and land the code
  change first. `test/mutant/baseline.yml` only records main's survivors as of
  its newest anchor, re-anchored with `bin/mutant-floor --record "REASON"`.
- **Duplication and complexity** (exhale, run from its own bundle in
  `tools/Gemfile`) fail only on what the change introduces since the merge
  base: a new copy, or a method whose cognitive complexity rises above 8.
  Copies already on main are warnings.
- **The guards and the test count** compare with the merge base. They fail on
  a file under `app/` or `lib/` that exhale no longer reads, on more RuboCop
  or `mutant:disable` directives in a file, on any failure or error, and on
  fewer tests than the base or a skip, unless `test/ci/test_removals.yml`
  lists it with a reason.

Don't edit a baseline, `test/mutant/accepted.yml`, `test/ci/test_removals.yml`
or any path in `.github/CODEOWNERS` to get a pass. Those paths need the
owner's approval, so a PR that must change one says why. A merge to `main`
deploys to production.

## Testing

Minitest with fixtures (`test/fixtures/*.yml`). `test/integration/site_flow_test.rb`
covers public rendering, auth redirects, and admin CRUD. The Contracts' tests
live under `test/contract/`. Add or adjust tests when you change behavior, and
run `bin/ci`, the full check, before finishing; `bin/rails test` and
`bin/rubocop` are its quick parts.

`test/design/` holds the design system's guards, and they are not optional:

- **`contrast_test.rb`** parses the OKLCH values out of `themes.css`, converts
  them to sRGB, and asserts WCAG AA on every meaningful pair across all four
  presets in both modes. It discovers presets from the stylesheet, so a new
  preset is covered the moment it is added.
- **`stylesheet_test.rb`** enforces the structural rules: balanced comments and
  braces, no hardcoded colors, no preset names outside `themes.css`, no
  undefined custom properties, and `SiteSetting::PRESETS` in agreement with the
  stylesheet.

If a token change fails one of these, the token is wrong. Do not relax the test.

### Mutation testing

[mutant](https://github.com/mbj/mutant) checks that a Contract's tests would
notice the code changing. It is configured in `config/mutant.yml`:

```bash
bundle exec mutant run                      # every subject listed under matcher.subjects
bundle exec mutant run 'MarkdownRenderer*'  # one subject; also 'MarkdownRenderer#render'
```

A mutant left alive is a change no test noticed, and mutant exits nonzero while
any survive. Mutant only runs tests that declare what they cover, so a new
contract test opens with

```ruby
cover "Subject*" if respond_to?(:cover)
```

The guard matters: `cover` exists only under mutant, so without it
`bin/rails test` raises. Add the subject to `matcher.subjects` too. Mutant loads
only test files with a `cover` line (`test/mutant/boot.rb`), and gives each
worker its own copy of the test database (`test/mutant/hooks.rb`).
