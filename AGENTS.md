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
bin/rails db:seed     # admin user + starter content (ADMIN_EMAIL / ADMIN_PASSWORD to override)
bin/rails server      # http://localhost:3000  (admin at /admin)
bin/rails test        # Minitest suite — keep it green
bin/rubocop           # rails-omakase style — keep it clean
```

## Architecture

### Content model (all editable at `/admin`)

- **`Section`** — static content blocks (Markdown `body`), grouped by `page`
  (`home`/`about`/`work`/`contact`), ordered by `position`, shown when
  `visible`. An optional `note` puts a short line in the page margin. Public pages render `Section.for_page(x).visible.ordered`.
- **`Post`** — Markdown blog posts, `draft`/`published` (enum), public at
  `/writing/:slug`. `published_at` is set automatically on publish.
- **`SiteSetting`** — key/value site-wide values (title, tagline, links,
  `hero_note`). Read via `SiteSetting["key"]`, which falls back to
  `SiteSetting::DEFAULTS`.

### The shell

The home page opens on a command line. Read **`SHELL.md`** before touching it:
it is the spec for the whole surface, including the FAQ matcher and grounded
model it is staged to grow into.

- **`Shell`** (`app/services/shell.rb`) interprets one line and returns a
  `Result` naming a partial under `app/views/shell/` plus its locals. It knows
  nothing about HTTP. Free text lands in `:unknown`, which is where later
  routes plug in.
- **`ShellController#show`** answers `GET /shell?line=...`: a Turbo Stream
  appending the exchange when JavaScript asked for one, otherwise a redirect
  to `/?line=...` so the home page renders the exchange after the opening.
  `open` and `lang` redirect instead.
- **The opening** is the `shell_opening` setting, `;`-separated commands run
  at render time. `whoami` prints `shell_whoami` (and `shell_whoami_es`).
- **`shell_controller.js`** plays the opening typed once per session, keeps
  history and Tab completion, and answers `theme`, `light`, `dark`, `clear`
  and `open` in the browser by calling the theme controller, so the switch
  has one code path. `Shell::CLIENT_SIDE` lists them so the server can say
  they need JavaScript when it is off.
- **Two languages.** `SiteController` picks the locale per request: the
  `locale` cookie set by `lang es`, then `Accept-Language`, then English. The
  chrome strings live in `config/locales/en.yml` and `es.yml` under one
  matching tree; a test fails if the two files disagree. Localised settings
  are sibling keys with a `_es` suffix read through `SiteSetting.localized`.
  The admin never switches.

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

Its Contract is in `PRODUCT.md` ("Contract: the Markdown renderer"), with the
reasons behind its choices in `DECISIONS.md`, and runs as
`test/contract/markdown_renderer_contract_test.rb`. Change the Contract and its
test first, then the code.

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

## Testing

Minitest with fixtures (`test/fixtures/*.yml`). `test/integration/site_flow_test.rb`
covers public rendering, auth redirects, and admin CRUD;
`test/integration/shell_test.rb` covers the shell over HTTP, both with and
without JavaScript, and `test/system/shell_test.rb` covers it as typed. Add or
adjust tests when you change behavior, and keep `bin/rails test` and
`bin/rubocop` green before finishing.

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
