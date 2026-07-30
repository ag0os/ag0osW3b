# ag0osW3b

Agustin Calabrese's personal website — a small, vanilla Rails app with a
Markdown blog and a simple admin for managing content.

## Stack

- Ruby 4.0.5 · Rails 8.1
- Propshaft · import maps · Hotwire (Turbo + Stimulus)
- Vanilla CSS design system: four theme presets, each in light and dark
- SQLite + Solid Queue/Cache/Cable
- commonmarker + rouge for Markdown posts

## Getting started

```bash
bin/setup            # install gems, prepare the database
bin/rails db:seed    # create the admin user + starter content
bin/rails server     # http://localhost:3000  (admin at /admin)
```

Set admin credentials with `ADMIN_EMAIL` / `ADMIN_PASSWORD` when seeding.
Run the tests with `bin/rails test`.

## Content

Content lives in the database and is managed at `/admin`: static `Section`
blocks (toggleable per page), Markdown `Post`s (draft/published), and key/value
`SiteSetting`s.

## Design

Four theme presets (`workshop`, `console`, `spec`, `terminal`), each shipping
light and dark. Visitors switch from the header; the site default is set at
`/admin/settings`. `DESIGN.md` documents the token contract, `PRODUCT.md` the
strategy behind it, and `test/design/` enforces both.
