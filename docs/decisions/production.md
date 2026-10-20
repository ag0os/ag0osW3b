# Decisions: the production deploy

### D-17. Production seeding requires `ADMIN_PASSWORD`, always

**Decision.** In production, `db/seeds.rb` raises before its first write when `ADMIN_PASSWORD` is unset or blank, even if the admin user exists. It never prints the password there. Development and test keep `change-me-please` and print it.

**Derivation.** The repository is public, so its default password is everyone's. Generating a random password instead would have to be printed to be useful, and printing is what PD-2 forbids. Checking only when the admin is about to be created would let a re-seed proceed without the variable, but would make the rule depend on database state the operator cannot see from the deploy screen; one rule with no exceptions is easier to trust. A blank value counts as unset because `has_secure_password` would reject it anyway, after the error message had lost the variable's name. Raising rather than `abort` makes `db:seed` exit nonzero with the message, so a deploy script stops. Obligations: PD-1 to PD-3.

### D-18. Mail links use `agoos.dev`, pinned by booting production

**Decision.** `config.action_mailer.default_url_options = { host: "agoos.dev" }` in `config/environments/production.rb`. Its test runs `bin/rails runner` with `RAILS_ENV=production` and `SECRET_KEY_BASE_DUMMY=1` and builds the password-reset URL with `PasswordsMailer`.

**Derivation.** The host is the domain the owner owns. The protocol needs no setting: with `force_ssl` on, Rails defaults Action Mailer's protocol to `https`, which `.dev` requires (HSTS preloaded). The test builds a real mail URL rather than reading the config line, so it also fails if the protocol default stops applying or an initializer overrides the host. Booting takes a few seconds and opens no database. The dummy secret is what `assets:precompile` uses for the same reason, so the test needs no master key. Obligation: PD-4.

### D-19. www redirects to the apex from the first route, in every environment

**Decision.** The first block in `config/routes.rb` is `constraints host: "www.agoos.dev"` around `match "(*path)", via: :all`, redirecting to `"https://agoos.dev#{request.fullpath}"`. `redirect` answers 301 by default.

**Derivation.** The owner chose the app over Caddy on 2026-10-16, after finding no Hatchbox setting for it, and Hatchbox documents this pattern. Being first means no other route can answer for www. The host is matched exactly, and the target is written out rather than derived by stripping `www.` from the request, so the redirect can only ever point at the domain the owner owns. `request.fullpath` carries the path and the query string as they arrived. `via: :all` covers every method because "any request" includes a form post or a feed reader's `HEAD`. A 301 lets a browser repeat a `POST` as a `GET`, which a 308 would not; nothing on the site is posted to from www, and the owner asked for 301, so 301 stands. The constraint applies in every environment: nothing reaches `www.agoos.dev` locally, so it changes nothing in development, and in test it lets `test/contract/canonical_host_contract_test.rb` run against the real route table. A production-only route could only be tested by booting production. `force_ssl` does not matter here: with `assume_ssl` on, Rails treats every request as https and never redirects one itself. Caddy upgrades http before the app sees it, so a visitor to `http://www.agoos.dev` takes Caddy's hop to https and then this one to the apex. Obligation: PD-5.
