require "test_helper"
require "open3"
require_relative "../mutant/floor"
require_relative "../ci/change_guards"
require_relative "../ci/test_count"

# Continuous integration's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("Contract: continuous integration"). CI-1 to CI-3,
# CI-6 and CI-8 read the config files; CI-4, CI-5, CI-7 and CI-9 run the
# floor's, the guards' and the test count's logic on hand-built inputs.
class CiContractTest < ActiveSupport::TestCase
  # Records config/ci.rb's steps instead of running them.
  class Recorder
    attr_reader :steps

    def initialize = @steps = []
    def run(&block) = instance_eval(&block)
    def step(title, *command) = @steps << [ title, command.join(" ") ]
    def success? = true
    def failure(*) = nil
  end

  def ci_steps(base: nil)
    recorder = Recorder.new
    previous = ENV["CI_BASE"]
    ENV["CI_BASE"] = base
    Object.const_set(:CI, recorder)
    load Rails.root.join("config/ci.rb").to_s
    recorder.steps
  ensure
    Object.send(:remove_const, :CI)
    ENV["CI_BASE"] = previous
  end

  def workflow = YAML.load_file(Rails.root.join(".github/workflows/ci.yml"))

  # --- What runs --------------------------------------------------------------

  test "CI-1 bin/ci runs every check, the guards and floors last, each against the base" do
    assert_equal [
      [ "Setup", "bin/setup --skip-server" ],
      [ "Style: Ruby", "bin/rubocop" ],
      [ "Security: Gem audit", "bin/bundler-audit" ],
      [ "Security: Importmap vulnerability audit", "bin/importmap audit" ],
      [ "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error" ],
      [ "Tests: Rails", "bin/test-count rails abc1234" ],
      [ "Tests: System", "bin/test-count system abc1234" ],
      [ "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant" ],
      [ "Guard: Files exhale doesn't read", "bin/change-guards unlisted abc1234" ],
      [ "Guard: Disable directives", "bin/change-guards directives abc1234" ],
      [ "Health: Mutation", "bin/mutant-floor abc1234" ],
      [ "Health: Duplication", "bin/exhale dry --base abc1234 --introduced-only" ],
      [ "Health: Complexity", "bin/exhale complexity --base abc1234" ]
    ], ci_steps(base: "abc1234")
  end

  test "CI-2 GitHub runs bin/ci and nothing else, in one job named ci, with the history" do
    assert_equal [ "ci" ], workflow.fetch("jobs").keys
    assert_equal [ "pull_request", "push" ], workflow.fetch(true).keys.sort # YAML reads `on:` as true
    assert_nil workflow.fetch(true).fetch("pull_request"), "a filter on pull_request leaves some pull requests unchecked"
    assert_equal({ "branches" => [ "main" ] }, workflow.fetch(true).fetch("push"))

    steps = workflow.dig("jobs", "ci", "steps")
    runs = steps.filter_map { |step| step["run"] }
    assert_equal [ "bin/ci" ], runs.grep_v(/\Asudo apt-get/)
    assert_match(/libvips/, runs.first)
    checkout = steps.find { |step| step["uses"].to_s.start_with?("actions/checkout") }
    assert_equal 0, checkout.dig("with", "fetch-depth")
    screenshots = steps.find { |step| step["name"] == "Keep screenshots from failed system tests" }
    assert_equal "failure()", screenshots["if"]
  end

  test "CI-2 the steps take no inputs or environment beyond what is pinned here" do
    job = workflow.dig("jobs", "ci")
    assert_equal %w[env runs-on steps timeout-minutes], job.keys.sort
    assert_equal [ "CI_BASE" ], job.fetch("env").keys

    pinned = {
      "actions/checkout@v6" => { "fetch-depth" => 0 },
      "ruby/setup-ruby@v1" => { "bundler-cache" => true }
    }
    job.fetch("steps").each do |step|
      assert_empty step.keys - %w[name run uses with if], "#{step["name"]} sets #{(step.keys - %w[name run uses with if]).join(", ")}"
      assert_equal pinned[step["uses"]], step["with"], "#{step["name"]} changes its inputs" if pinned.key?(step["uses"])
      assert_nil step["with"], "#{step["name"]} takes inputs" if step["run"]
    end
  end

  test "CI-2 nothing can skip the job or let it pass when bin/ci fails" do
    job = workflow.dig("jobs", "ci")
    assert_not job.key?("if"), "a skipped job passes a required check"
    assert_not job.key?("continue-on-error")

    job.fetch("steps").each do |step|
      assert_not step.key?("continue-on-error"), "#{step["name"]} continues on error"
      next unless step.key?("if")

      assert_equal "failure()", step["if"], "#{step["name"]} has a condition"
      assert_match %r{\Aactions/upload-artifact@}, step["uses"].to_s, "#{step["name"]} is conditional but uploads nothing"
    end
  end

  test "CI-2 every action the job uses is on the allowlist" do
    used = workflow.dig("jobs", "ci", "steps").filter_map { |step| step["uses"] }

    assert_empty used - %w[actions/checkout@v6 ruby/setup-ruby@v1 actions/upload-artifact@v4]
  end

  test "CI-3 the base is the target branch on a pull request, the previous main on a push, origin/main locally" do
    expression = workflow.dig("jobs", "ci", "env", "CI_BASE")
    assert_equal "${{ github.event_name == 'pull_request' && format('origin/{0}', github.base_ref) || github.event.before }}", expression

    assert_equal "bin/mutant-floor origin/main", ci_steps(base: nil).assoc("Health: Mutation").last
    assert_equal "bin/mutant-floor origin/main", ci_steps(base: "").assoc("Health: Mutation").last
  end

  # --- The mutation floor -------------------------------------------------------

  def coverage(diff, killed: false, timeout: false, type: "evil", id: "evil:X")
    { "criteria_result" => { "process_abort" => false, "test_result" => killed, "timeout" => timeout },
      "mutation_result" => { "mutation_type" => type, "mutation_diff" => diff, "mutation_identification" => id } }
  end

  def session(subjects, amounts = {})
    { "subject_results" => subjects.map do |name, coverages|
      { "expression_syntax" => name, "amount_mutations" => amounts.fetch(name, coverages.size), "coverage_results" => coverages }
    end }
  end

  def baseline(survivors) = { "anchors" => [ { "reason" => "accepted" } ], "survivors" => survivors }

  def compare(session, baseline, expressions: [ "Home*", "Pages*" ])
    MutantFloor.compare(session, baseline, expressions:)
  end

  DROP_ORDER = "@@ -1,4 +1,4 @@\n def show\n-  @sections = all.ordered\n+  @sections = all\n end\n"

  test "CI-4 a survivor in the baseline passes, wherever its method has moved and whatever else it holds" do
    moved = "@@ -3,6 +3,6 @@\n def show\n   log\n-  @sections = all.ordered\n+  @sections = all\n   @posts = recent\n end\n"
    neutral = coverage(nil, killed: true, type: "neutral") # mutant's run of the code as written: no diff
    verdict = compare(session("Home#show" => [ neutral, coverage(moved) ], "Pages#show" => []),
                      baseline("Home#show" => [ "-  @sections = all.ordered\n+  @sections = all" ]))

    assert verdict.pass?
  end

  test "CI-4 a survivor not in the baseline fails, and is named" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, id: "evil:Home#show:1:abc") ], "Pages#show" => []), baseline({}))

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", "-  @sections = all.ordered\n+  @sections = all", "evil:Home#show:1:abc" ] ],
                 verdict.new_survivors.map { |s| [ s.subject, s.change, s.identification ] }
  end

  test "CI-4 the same change in another subject is a different survivor" do
    verdict = compare(session("Home#show" => [], "Pages#show" => [ coverage(DROP_ORDER) ]),
                      baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_equal [ "Pages#show" ], verdict.new_survivors.map(&:subject)
  end

  test "CI-4 each baseline entry accepts one survivor" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_ORDER) ], "Pages#show" => []),
                      baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_equal 1, verdict.new_survivors.size
  end

  test "CI-4 a neutral mutation the tests fail on fails, whatever the baseline holds" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, type: "neutral") ], "Pages#show" => []),
                      baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_not verdict.pass?
    assert_equal [ "Home#show" ], verdict.broken.map(&:subject)
  end

  test "CI-4 a subject with fewer results than mutations fails" do
    verdict = compare(session({ "Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => [] }, { "Home#show" => 2 }),
                      baseline({}))

    assert_not verdict.pass?
    assert_equal [ "Home#show" ], verdict.partial
  end

  test "CI-4 an expression in config/mutant.yml that matches no subject fails" do
    verdict = compare(session("Home#show" => [], "Pages#show" => []), baseline({}), expressions: [ "Home*", "Pages#show", "Gone*", "Pages#gone" ])

    assert_not verdict.pass?
    assert_equal [ "Gone*", "Pages#gone" ], verdict.unmatched
  end

  test "CI-4 an expression matches its namespace and what it nests, not a longer name" do
    subjects = session("Home#show" => [], "Home::Card.build" => [], "Homepage#show" => [])

    assert_empty compare(subjects, baseline({}), expressions: [ "Home*", "Homepage#show" ]).unmatched
    assert_equal [ "Home::Card*" ], compare(session("Homepage#show" => []), baseline({}), expressions: [ "Home::Card*" ]).unmatched
    assert_equal [ "Hom*" ], compare(subjects, baseline({}), expressions: [ "Hom*" ]).unmatched
  end

  test "CI-4 a subject the baseline names that matches no subject fails" do
    verdict = compare(session("Home#show" => [], "Pages#show" => []), baseline("Home#index" => [ "-a\n+b" ]))

    assert_not verdict.pass?
    assert_equal [ "Home#index" ], verdict.unmatched
  end

  test "CI-4 a subject the baseline records that no longer runs fails, entries or not" do
    recorded = baseline({}).merge("subjects" => [ "Home#index", "Home#show", "Pages#show" ])
    verdict = compare(session("Home#show" => [], "Pages#show" => []), recorded)

    assert_not verdict.pass?
    assert_equal [ "Home#index" ], verdict.unmatched
  end

  test "CI-4 a subject that runs but isn't recorded yet passes" do
    recorded = baseline({}).merge("subjects" => [ "Home#show" ])

    assert compare(session("Home#show" => [], "Pages#show" => []), recorded).pass?
  end

  test "CI-4 a baseline entry whose mutation a test now kills fails" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => []),
                      baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", MutantFloor.change(DROP_ORDER) ] ], verdict.killed
  end

  test "CI-4 a baseline entry whose mutation mutant no longer makes fails" do
    verdict = compare(session("Home#show" => [], "Pages#show" => []), baseline("Home#show" => [ "-a\n+b" ]))

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", "-a\n+b" ] ], verdict.vanished
  end

  test "CI-4 a baseline entry whose mutation only timed out passes, and is reported" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, timeout: true) ], "Pages#show" => []),
                      baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert verdict.pass?
    assert_equal [ [ "Home#show", MutantFloor.change(DROP_ORDER) ] ], verdict.timed_out
  end

  test "CI-5 changing the baseline's survivors needs a new anchor with a reason" do
    base = baseline("Home#show" => [ "-a\n+b" ])
    grown = ->(anchors) { { "anchors" => anchors, "survivors" => { "Home#show" => [ "-a\n+b", "-c\n+d" ] } } }

    assert_nil MutantFloor.anchor_problem(base, base)
    assert_match(/without adding an anchor/, MutantFloor.anchor_problem(grown.(base["anchors"]), base))
    assert_match(/gives no reason/, MutantFloor.anchor_problem(grown.(base["anchors"] + [ { "reason" => " " } ]), base))
    assert_nil MutantFloor.anchor_problem(grown.(base["anchors"] + [ { "reason" => "c+d is equivalent" } ]), base)
    assert_match(/without adding an anchor/, MutantFloor.anchor_problem({ "survivors" => {} }, nil))
    assert_nil MutantFloor.anchor_problem(base, nil)
  end

  test "CI-5 changing the subjects the baseline records needs a new anchor with a reason" do
    base = baseline({}).merge("subjects" => [ "Home#index", "Home#show" ])
    shrunk = ->(anchors) { base.merge("anchors" => anchors, "subjects" => [ "Home#show" ]) }

    assert_match(/without adding an anchor/, MutantFloor.anchor_problem(shrunk.(base["anchors"]), base))
    assert_nil MutantFloor.anchor_problem(shrunk.(base["anchors"] + [ { "reason" => "index moved to a concern" } ]), base)
  end

  test "CI-5 recording writes every subject that ran, with or without survivors" do
    ran = session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [ coverage(DROP_ORDER, killed: true) ])
    recorded = MutantFloor.record(ran, {}, at: "abc1234", on: "2026-10-16", reason: "first")

    assert_equal [ "Home#show", "Pages#show" ], recorded["subjects"]
    assert_equal({ "Home#show" => [ MutantFloor.change(DROP_ORDER) ] }, recorded["survivors"])
    assert_equal [ { "at" => "abc1234", "on" => "2026-10-16", "reason" => "first" } ], recorded["anchors"]
  end

  # --- Exhale's bundle ------------------------------------------------------------

  test "CI-6 exhale runs from tools/Gemfile and stays out of the app's bundle" do
    assert_no_match(/exhale/, Rails.root.join("Gemfile").read)
    assert_no_match(/^\s+exhale /, Rails.root.join("Gemfile.lock").read)
    assert_match(/^\s+exhale \(/, Rails.root.join("tools/Gemfile.lock").read)

    out, status = Bundler.with_unbundled_env { Open3.capture2e(Rails.root.join("bin/exhale").to_s, "--version") }
    assert status.success?, out
    assert_match(/0\.2\.0/, out)
  end

  test "CI-6 bin/exhale leaves the app's lockfile alone, whatever bundle it is started from" do
    lockfile = Rails.root.join("Gemfile.lock")
    before = lockfile.read
    # bin/ci's children inherit its bundle: BUNDLE_GEMFILE, BUNDLE_LOCKFILE,
    # and RUBYOPT, which loads it. With and without RUBYOPT:
    [ {}, { "RUBYOPT" => nil } ].each do |env|
      out, status = Open3.capture2e(env, Rails.root.join("bin/exhale").to_s, "--version")
      assert status.success?, out
      assert_equal before, lockfile.read, "bin/exhale rewrote Gemfile.lock"
    end
  ensure
    lockfile.write(before) if before
  end

  test "CI-6 exhale's bundle is frozen: a Gemfile that no longer matches its lockfile fails" do
    Dir.mktmpdir do |dir|
      FileUtils.cp(%w[Gemfile Gemfile.lock boot.rb].map { |name| Rails.root.join("tools", name) }, dir)
      File.write(File.join(dir, "Gemfile"), "gem \"rake\"\n", mode: "a")
      out, status = Bundler.with_unbundled_env { Open3.capture2e("ruby", "-e", "require #{File.join(dir, "boot").dump}") }

      assert_not status.success?, out
      assert_equal "gem \"rake\"\n", File.read(File.join(dir, "Gemfile")).lines.last
      assert_no_match(/rake/, File.read(File.join(dir, "Gemfile.lock")))
    end
  end

  # --- The guards -------------------------------------------------------------------

  RUBOCOP = "# rubo" + "cop:disable Rails/OutputSafety"
  MUTANT = "mutant" + ":disable"

  test "CI-7 a file exhale stops reading fails; one it never read, or that is gone, passes" do
    base_candidates = %w[app/a.rb app/b.rb app/c_test.rb app/d.rb]
    base_listed = %w[app/a.rb app/b.rb app/d.rb]
    head_candidates = %w[app/a.rb app/b.rb app/c_test.rb app/ab_test.rb lib/gen.rb]
    head_listed = %w[app/a.rb]

    assert_equal %w[app/ab_test.rb app/b.rb lib/gen.rb],
                 ChangeGuards.newly_unlisted(head_candidates, head_listed, base_candidates, base_listed)
  end

  test "CI-7 exhale leaves out the files the guard relies on it to name" do
    Dir.mktmpdir do |dir|
      files = {
        "app/models/plain.rb" => "class Plain\nend\n",
        "app/models/ab_test.rb" => "class AbTest\nend\n",
        "app/models/generated.rb" => "# Do not edit by hand.\nclass Generated\nend\n",
        "app/views/presets/spec/show.html.erb" => "<p>spec</p>\n",
        "app/.hidden/x.rb" => "X = 1\n"
      }
      files.each { |path, text| FileUtils.mkdir_p(File.join(dir, File.dirname(path))) && File.write(File.join(dir, path), text) }
      script = "require 'exhale'; print Exhale::SourceFiles.list(ARGV[0], files: ARGV[1..]).map(&:first).join(' ')"
      out, status = Bundler.with_unbundled_env do
        Open3.capture2e({ "BUNDLE_GEMFILE" => Rails.root.join("tools/Gemfile").to_s },
                        "ruby", "-rbundler/setup", "-e", script, dir, *files.keys)
      end

      assert status.success?, out
      assert_equal "app/models/plain.rb", out
    end
  end

  test "CI-7 a file with more RuboCop disable or todo directives than at the base fails" do
    base = { "app/a.rb" => "x = 1 #{RUBOCOP}\n", "app/b.rb" => "y\n" }
    head = {
      "app/a.rb" => "x = 1 #{RUBOCOP}\nz = 2\n",
      "app/b.rb" => "y #{RUBOCOP.sub("disable", "todo")}\n",
      "app/c.rb" => "  #   rubo#{"cop"} : disable all\n"
    }

    assert_equal [ [ "app/b.rb", :rubocop, 0, 1 ], [ "app/c.rb", :rubocop, 0, 1 ] ], ChangeGuards.added_directives(base, head)
    assert_empty ChangeGuards.added_directives(head, base)
  end

  test "CI-7 a file with more mutant disable comments than at the base fails, written as mutant reads them" do
    head = {
      "app/a.rb" => "# #{MUTANT}\ndef a; end\n",
      "app/b.rb" => "##{MUTANT}\ndef b; end\n",
      "app/c.rb" => "def c; end # #{MUTANT} because\n",
      "app/d.rb" => "# not-#{MUTANT}d\ndef d; end\n"
    }

    assert_equal [ [ "app/a.rb", :mutant, 0, 1 ], [ "app/b.rb", :mutant, 0, 1 ], [ "app/c.rb", :mutant, 0, 1 ] ],
                 ChangeGuards.added_directives({}, head)
  end

  test "CI-7 the mutant pattern is mutant's own" do
    out, status = Open3.capture2e("ruby", "-rbundler/setup", "-e", "require 'mutant'; print Mutant::Subject::Config::DISABLE_REGEXP.source")

    assert status.success?, out
    assert_equal out.lines.last, ChangeGuards::MUTANT_DISABLE.source
  end

  # --- Who may change the gate ------------------------------------------------------

  def code_owners
    Rails.root.join(".github/CODEOWNERS").read.lines.filter_map do |line|
      pattern, *names = line.sub(/#.*/, "").split
      [ pattern, names ] if pattern
    end.to_h
  end

  test "CI-8 CODEOWNERS names the owner on every path that decides the gate" do
    owners = code_owners

    %w[
      /.github/ /bin/ /config/ci.rb /config/mutant.yml /test/mutant/ /test/ci/ /test/contract/ci_contract_test.rb
      /contract/ /tools/ /tmp/ /.rubocop.yml /.rubocop /config/brakeman.yml /config/brakeman.ignore /config/bundler-audit.yml
      /.bundle/ /vendor/bundle/ /.gitattributes
      /test/test_helper.rb /test/test_helpers/ /test/application_system_test_case.rb /config/environments/test.rb
      /config/boot.rb /Rakefile /lib/tasks/ /Gemfile
    ].each { |path| assert_equal [ "@ag0os" ], owners[path], "#{path} has no code owner" }
  end

  test "CI-8 CODEOWNERS leaves the app's lockfile unowned, so a lockfile-only bump can merge on a green check" do
    owning = code_owners.keys.select do |pattern|
      anchored = pattern.start_with?("/") ? pattern : "**/#{pattern}"
      File.fnmatch?(anchored.delete_prefix("/"), "Gemfile.lock", File::FNM_PATHNAME | File::FNM_DOTMATCH)
    end

    assert_empty owning, "Gemfile.lock is owned by #{owning.join(", ")}"
  end

  # --- The test count ---------------------------------------------------------------

  SUMMARY = "Finished in 3.1s, 60 runs/s.\n210 runs, 1428 assertions, 0 failures, 0 errors, 0 skips\n"

  def count(output = SUMMARY, success: true, base: 210, head_removals: [], base_removals: [], skips: [])
    TestCount.problems(output:, success:, base_count: base, suite: "rails", head_removals:, base_removals:, skips:)
  end

  test "CI-9 a run that ends with the summary, no failures or errors, and the base's count passes" do
    assert_empty count
    assert_empty count(SUMMARY, base: 205)
  end

  test "CI-9 a run with no summary fails, even when it exits 0" do
    assert_match(/no Minitest summary/, count("", success: true).join)
    assert_match(/no Minitest summary/, count("Run options: --seed 1\n", success: true).join)
  end

  test "CI-9 a run with failures or errors, or that exits nonzero, fails" do
    assert_match(/1 failures, 0 errors/, count(SUMMARY.sub("0 failures", "1 failures")).join)
    assert_match(/0 failures, 2 errors/, count(SUMMARY.sub("0 errors", "2 errors")).join)
    assert_match(/exited nonzero/, count(SUMMARY, success: false).join)
  end

  test "CI-9 fewer runs than the base has tests fails, unless a removal this change adds gives the reason" do
    removal = { "suite" => "rails", "tests" => 2, "reason" => "the shell's tests went with the shell" }

    assert_match(/210 runs, but the base has 212 tests/, count(SUMMARY, base: 212).join)
    assert_empty count(SUMMARY, base: 212, head_removals: [ removal ])
    assert_match(/but the base has 212/, count(SUMMARY, base: 212, head_removals: [ removal ], base_removals: [ removal ]).join)
    assert_match(/but the base has 213/, count(SUMMARY, base: 213, head_removals: [ removal ]).join)
    assert_match(/but the base has 212/, count(SUMMARY, base: 212, head_removals: [ removal.merge("suite" => "system") ]).join)
    assert_match(/gives no reason/, count(SUMMARY, base: 212, head_removals: [ removal.merge("reason" => " ") ]).join)
  end

  test "CI-9 a skipped test fails unless test_removals.yml lists it with a reason" do
    skipped = SUMMARY.sub("0 skips", "7 skips")
    listed = { "suite" => "rails", "tests" => 7, "reason" => "the admin suite waits on the new login" }

    assert_match(/7 skips, but test_removals.yml lists 0/, count(skipped).join)
    assert_empty count(skipped, skips: [ listed ])
    assert_match(/7 skips, but test_removals.yml lists 0/, count(skipped, skips: [ listed.merge("suite" => "system") ]).join)
    assert_match(/gives no reason/, count(skipped, skips: [ listed.merge("reason" => "") ]).join)
  end

  test "CI-9 a listed skip that no longer skips fails, so the list comes off" do
    assert_match(/0 skips, but test_removals.yml lists 2/, count(SUMMARY, skips: [ { "suite" => "rails", "tests" => 2, "reason" => "flaky" } ]).join)
  end

  test "CI-9 a base with no tests fails, since an export or count went wrong" do
    assert_match(/the base has no rails tests/, count(SUMMARY, base: 0).join)
  end
end
