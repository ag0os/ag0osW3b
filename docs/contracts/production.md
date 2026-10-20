---
component: production
covers:
  - db/seeds.rb
  - config/environments/production.rb
  - config/routes.rb
depends_on: []
tests:
  - test/contract/production_contract_test.rb
  - test/contract/canonical_host_contract_test.rb
---
Coverage: 5 obligations; 5 proved by test, 0 by PR evidence, 0 mixed, 0 unproved. Suite runs against this implementation.

# Contract: the production deploy

What the first deploy to agoos.dev depends on. Moved without changing obligation meanings on 2026-10-20.

### PD-1 Production seeding requires a password before any write

In production, `db/seeds.rb` raises unless `ADMIN_PASSWORD` is set and not blank, with a message that names `ADMIN_PASSWORD`, before it writes anything: no user, section, setting or post. That holds whether or not the admin user already exists.

**Reason.** the repository is public, so the development default password is public, and an admin created with it on the live site is an open door. Failing before the first write leaves the database as it was, so setting the variable and seeding again is the whole fix. (D-17)

Kind: functional. Proof: test, PD-1 in `test/contract/production_contract_test.rb`.

### PD-2 Production seeds never print the password

In production with `ADMIN_PASSWORD` set, seeding creates the admin with that password, and nothing it prints contains the password.

**Reason.** deploy output goes to logs that outlive the session, and a password in a log is shared with whoever reads the log. (D-17)

Kind: functional. Proof: test, PD-2 in `test/contract/production_contract_test.rb`.

### PD-3 Local seeds keep the development password

In development and test, seeding without `ADMIN_PASSWORD` creates the admin with the default password, `change-me-please`, and prints it.

**Reason.** a local database needs an admin someone can log in as without setup. (D-17)

Kind: functional. Proof: test, PD-3 in `test/contract/production_contract_test.rb`.

### PD-4 Production mail links use HTTPS on agoos.dev

In production, links in mail are built for `https://agoos.dev`: the password-reset link is `https://agoos.dev/passwords/<token>/edit`. The test boots the production environment in a separate process and builds the link there.

**Reason.** the password-reset mail is the only way back into the admin, and a link to `example.com` leads nowhere. `.dev` is HTTPS only (HSTS preloaded), so an `http` link would depend on the browser to upgrade it. (D-18)

Kind: functional. Proof: test, PD-4 in `test/contract/production_contract_test.rb`.

### PD-5 The www host redirects to the apex

Any request to host `www.agoos.dev`, whatever its method or path, answers a permanent redirect (301) to `https://agoos.dev` with the same path and query string. Requests to `agoos.dev` are unaffected.

**Reason.** the site should have one canonical address, so it doesn't appear twice to visitors and search engines. The owner chose to do this in the app rather than in the server's Caddy config (2026-10-16), following Hatchbox's documented approach: a host-constrained route placed first in `config/routes.rb`. (D-19)

Kind: functional. Proof: test, PD-5 in `test/contract/canonical_host_contract_test.rb`.

## Decisions

- D-17, `docs/decisions/production.md`: production password and local defaults (PD-1 to PD-3).
- D-18, `docs/decisions/production.md`: production mail host (PD-4).
- D-19, `docs/decisions/production.md`: www redirects first (PD-5).
