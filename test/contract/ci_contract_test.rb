require "test_helper"
require_relative "../mutant/floor"

# Continuous integration's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("Contract: continuous integration"). CI-1 to CI-3
# read config/ci.rb and the workflow; CI-4 and CI-5 run the mutation floor's
# matching on hand-built mutant session results.
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

  test "CI-1 bin/ci runs every check, the floors last, each against the base" do
    assert_equal [
      [ "Setup", "bin/setup --skip-server" ],
      [ "Style: Ruby", "bin/rubocop" ],
      [ "Security: Gem audit", "bin/bundler-audit" ],
      [ "Security: Importmap vulnerability audit", "bin/importmap audit" ],
      [ "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error" ],
      [ "Tests: Rails", "bin/rails test" ],
      [ "Tests: System", "bin/rails test:system" ],
      [ "Tests: Seeds", "env RAILS_ENV=test bin/rails db:seed:replant" ],
      [ "Health: Mutation", "bin/mutant-floor abc1234" ],
      [ "Health: Duplication", "bin/exhale dry --base abc1234 --introduced-only" ],
      [ "Health: Complexity", "bin/exhale complexity --base abc1234" ]
    ], ci_steps(base: "abc1234")
  end

  test "CI-2 GitHub runs bin/ci and nothing else, in one job named ci, with the history" do
    assert_equal [ "ci" ], workflow.fetch("jobs").keys
    assert_equal [ "pull_request", "push" ], workflow.fetch(true).keys.sort # YAML reads `on:` as true
    assert_equal [ "main" ], workflow.fetch(true).fetch("push").fetch("branches")

    steps = workflow.dig("jobs", "ci", "steps")
    runs = steps.filter_map { |step| step["run"] }
    assert_equal [ "bin/ci" ], runs.grep_v(/\Asudo apt-get/)
    assert_match(/libvips/, runs.first)
    checkout = steps.find { |step| step["uses"].to_s.start_with?("actions/checkout") }
    assert_equal 0, checkout.dig("with", "fetch-depth")
    screenshots = steps.find { |step| step["name"] == "Keep screenshots from failed system tests" }
    assert_equal "failure()", screenshots["if"]
  end

  test "CI-3 the base is the target branch on a pull request, the previous main on a push, origin/main locally" do
    expression = workflow.dig("jobs", "ci", "env", "CI_BASE")
    assert_equal "${{ github.event_name == 'pull_request' && format('origin/{0}', github.base_ref) || github.event.before }}", expression

    assert_equal "bin/mutant-floor origin/main", ci_steps(base: nil).assoc("Health: Mutation").last
    assert_equal "bin/mutant-floor origin/main", ci_steps(base: "").assoc("Health: Mutation").last
  end

  # --- The mutation floor -------------------------------------------------------

  def coverage(diff, killed: false, type: "evil", id: "evil:X")
    { "criteria_result" => { "process_abort" => false, "test_result" => killed, "timeout" => false },
      "mutation_result" => { "mutation_type" => type, "mutation_diff" => diff, "mutation_identification" => id } }
  end

  def session(subjects)
    { "subject_results" => subjects.map { |name, coverages| { "expression_syntax" => name, "coverage_results" => coverages } } }
  end

  def baseline(survivors) = { "anchors" => [ { "reason" => "accepted" } ], "survivors" => survivors }

  DROP_ORDER = "@@ -1,4 +1,4 @@\n def show\n-  @sections = all.ordered\n+  @sections = all\n end\n"

  test "CI-4 a survivor in the baseline passes, wherever its method has moved and whatever else it holds" do
    moved = "@@ -3,6 +3,6 @@\n def show\n   log\n-  @sections = all.ordered\n+  @sections = all\n   @posts = recent\n end\n"
    verdict = MutantFloor.compare(session("Home#show" => [ coverage(moved) ]),
                                  baseline("Home#show" => [ "-  @sections = all.ordered\n+  @sections = all" ]))

    assert verdict.pass?
    assert_empty verdict.stale
  end

  test "CI-4 a survivor not in the baseline fails, and is named" do
    verdict = MutantFloor.compare(session("Home#show" => [ coverage(DROP_ORDER, id: "evil:Home#show:1:abc") ]), baseline({}))

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", "-  @sections = all.ordered\n+  @sections = all", "evil:Home#show:1:abc" ] ],
                 verdict.new_survivors.map { |s| [ s.subject, s.change, s.identification ] }
  end

  test "CI-4 the same change in another subject is a different survivor" do
    verdict = MutantFloor.compare(session("Pages#show" => [ coverage(DROP_ORDER) ]),
                                  baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_equal [ "Pages#show" ], verdict.new_survivors.map(&:subject)
  end

  test "CI-4 each baseline entry accepts one survivor" do
    verdict = MutantFloor.compare(session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_ORDER) ]),
                                  baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_equal 1, verdict.new_survivors.size
  end

  test "CI-4 killed mutations pass, and baseline entries now killed are reported without failing" do
    verdict = MutantFloor.compare(session("Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => []),
                                  baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ], "Other#run" => [ "-a\n+b" ]))

    assert verdict.pass?
    assert_equal [ [ "Home#show", MutantFloor.change(DROP_ORDER) ] ], verdict.stale
  end

  test "CI-4 a neutral mutation the tests fail on fails, whatever the baseline holds" do
    verdict = MutantFloor.compare(session("Home#show" => [ coverage(DROP_ORDER, type: "neutral") ]),
                                  baseline("Home#show" => [ MutantFloor.change(DROP_ORDER) ]))

    assert_not verdict.pass?
    assert_equal [ "Home#show" ], verdict.broken.map(&:subject)
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
end
