# Run using bin/ci. Everything a change must pass before it merges; GitHub runs
# exactly this. See PRODUCT.md, "Contract: continuous integration".

# What the test counts, guards and floors compare against. GitHub sets CI_BASE; locally it is
# origin/main, so fetch first.
base = ENV["CI_BASE"].to_s.then { |ref| ref.empty? ? "origin/main" : ref }

CI.run do
  step "Setup", "bin/setup --skip-server"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  # Each suite passes on Minitest's summary and the base's test count (CI-9).
  step "Tests: Rails", "bin/test-count", "rails", base
  step "Tests: System", "bin/test-count", "system", base
  step "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant"

  # Guards: changes that would switch a check off from inside the code.
  step "Guard: Files exhale doesn't read", "bin/change-guards", "unlisted", base
  step "Guard: Disable directives", "bin/change-guards", "directives", base

  # The mutation gate and the floors: each fails only on what the change adds since the base.
  step "Gate: Mutation", "bin/mutant-floor", base
  step "Health: Duplication", "bin/exhale", "dry", "--base", base, "--introduced-only"
  step "Health: Complexity", "bin/exhale", "complexity", "--base", base

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
