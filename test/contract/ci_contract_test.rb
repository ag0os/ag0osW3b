require "test_helper"
require "open3"
require_relative "../mutant/floor"
require_relative "../ci/change_guards"

# Continuous integration's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("Contract: continuous integration"). CI-1 to CI-3,
# CI-6 and CI-8 read the config files; CI-4, CI-5 and CI-7 run the floor's and
# the guards' logic on hand-built inputs.
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
      [ "Tests: Rails", "bin/rails test" ],
      [ "Tests: System", "bin/rails test:system" ],
      [ "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant" ],
      [ "Guard: Generator headers", "bin/change-guards headers abc1234" ],
      [ "Guard: RuboCop disables", "bin/change-guards rubocop abc1234" ],
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

  # --- The guards -------------------------------------------------------------------

  DIRECTIVE = "# rubo" + "cop:disable Rails/OutputSafety"

  test "CI-7 a file in app/ or lib/ that gains a generator header fails; one that had it passes" do
    pairs = [
      [ "app/helpers/a_helper.rb", "module A\nend\n", "# Do not edit by hand.\nmodule A\nend\n" ],
      [ "app/views/b.html.erb", nil, "<p>\n</p>\n\n\n<%# This file is auto-generated %>\n" ],
      [ "lib/c.rb", "# Generated by protoc. DO NOT EDIT.\n", "# Generated by protoc. DO NOT EDIT.\nX = 1\n" ],
      [ "app/models/d.rb", nil, "class D\n  # generated thumbnails are cached\nend\n" ],
      [ "app/models/e.rb", nil, "\n\n\n\n\n# Do not edit\n" ],
      [ "config/f.rb", nil, "# Do not edit\n" ]
    ]

    assert_equal [ "app/helpers/a_helper.rb", "app/views/b.html.erb" ], ChangeGuards.new_headers(pairs)
  end

  test "CI-7 the header pattern is exhale's own" do
    out, status = Bundler.with_unbundled_env do
      Open3.capture2e({ "BUNDLE_GEMFILE" => Rails.root.join("tools/Gemfile").to_s },
                      "ruby", "-rbundler/setup", "-rexhale", "-e", "print Exhale::SourceFiles::GENERATED.source")
    end
    assert status.success?, out
    assert_equal out, ChangeGuards::GENERATED.source
  end

  test "CI-7 a file with more RuboCop disable or todo directives than at the base fails" do
    base = { "app/a.rb" => "x = 1 #{DIRECTIVE}\n", "app/b.rb" => "y\n" }
    head = {
      "app/a.rb" => "x = 1 #{DIRECTIVE}\nz = 2\n",
      "app/b.rb" => "y #{DIRECTIVE.sub("disable", "todo")}\n",
      "app/c.rb" => "  #   rubo#{"cop"} : disable all\n"
    }

    assert_equal [ [ "app/b.rb", 0, 1 ], [ "app/c.rb", 0, 1 ] ], ChangeGuards.added_directives(base, head)
    assert_empty ChangeGuards.added_directives(head, base)
  end

  # --- Who may change the gate ------------------------------------------------------

  test "CI-8 CODEOWNERS names the owner on every path that decides the gate" do
    owners = Rails.root.join(".github/CODEOWNERS").read.lines.filter_map do |line|
      pattern, *names = line.sub(/#.*/, "").split
      [ pattern, names ] if pattern
    end.to_h

    %w[
      /.github/ /bin/ /config/ci.rb /config/mutant.yml /test/mutant/ /test/ci/ /test/contract/ci_contract_test.rb
      /contract/ /tools/ /.rubocop.yml /config/brakeman.ignore /config/bundler-audit.yml /Gemfile /Gemfile.lock
    ].each { |path| assert_equal [ "@ag0os" ], owners[path], "#{path} has no code owner" }
  end
end
