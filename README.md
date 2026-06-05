# ag0osW3b

Agustin Calabrese's personal website — a vanilla Rails app that presents an
approved bio, positioning, public project links, and a Markdown blog, all
managed through a small admin. Content lives in this app's database; it is
curated, one-way, from a separate private knowledge base.

## Stack

- **Ruby 4.0.5 · Rails 8.1** (vanilla — no Tailwind, no Node build step)
- **Propshaft** assets · **import maps** · **Hotwire** (Turbo + Stimulus)
- **Vanilla CSS** with custom-property design tokens (light/dark theme switch)
- **SQLite + Solid** Queue/Cache/Cable
- Built-in Rails **authentication** generator (single admin user)
- **commonmarker** + **rouge** for Markdown posts with class-based syntax highlighting

## Getting started

```bash
bin/setup            # install gems, prepare the database
bin/rails db:seed    # create the admin user + initial content
bin/rails server     # http://localhost:3000
```

Seeds create an admin user. Override the credentials:

```bash
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD=secret bin/rails db:seed
```

The default password is `change-me-please` — change it after first login.

Run the tests:

```bash
bin/rails test
```

## Content model

Everything editable lives in three models, managed at **`/admin`**:

| Model         | Purpose                                                              |
|---------------|---------------------------------------------------------------------|
| `Section`     | Static content blocks, grouped by `page` (home/about/work/contact). Toggle `visible` to show/hide on the live site; `position` orders them. |
| `Post`        | Blog posts (Markdown), `draft` or `published`. Public at `/writing/:slug`. |
| `SiteSetting` | Key/value site-wide values (title, tagline, contact links). Falls back to `SiteSetting::DEFAULTS`. |

Public pages render only `visible` sections and `published` posts. The admin is
login-only; the rest of the site is public.

## Theming

Themes are plain CSS custom properties in `app/assets/stylesheets/application.css`
(`:root` and `[data-theme="dark"]`). A small Stimulus controller
(`theme_controller.js`) flips `data-theme` on `<html>` and persists the choice;
an inline script in the layout applies it before first paint to avoid a flash.

## Deployment — Hatchbox Pro → DigitalOcean

Deploys are git-based via Hatchbox (Puma + nginx + Let's Encrypt). No Kamal/Docker.

1. Connect the GitHub repo to the Hatchbox app.
2. Set env vars in Hatchbox: **`RAILS_MASTER_KEY`** (from `config/master.key`).
3. **SQLite persistence (important):** the database lives in `storage/`
   (`config/database.yml` → `storage/production.sqlite3`, plus the Solid
   cache/queue/cable files). `storage/` **must be a Hatchbox shared/persisted
   directory**, or the database resets on every deploy.
4. Deploy command runs `db:prepare` (creates + migrates primary and the
   Solid databases). Seed once after the first deploy.
5. Solid Queue runs inside Puma (`SOLID_QUEUE_IN_PUMA`) — no separate worker.

`.ruby-version` pins **4.0.5** so Hatchbox installs the matching Ruby.
