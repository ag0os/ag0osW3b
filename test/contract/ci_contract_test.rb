require "test_helper"
require "open3"
require_relative "../mutant/floor"
require_relative "../ci/change_guards"
require_relative "../ci/test_count"

# Continuous integration's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("Contract: continuous integration"). CI-1 to CI-3,
# CI-6 and CI-8 read the config files; CI-4, CI-5, CI-7 and CI-9 run the
# mutation gate's, the guards' and the test count's logic on hand-built inputs.
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
      [ "Gate: Mutation", "bin/mutant-floor abc1234" ],
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

    assert_equal "bin/mutant-floor origin/main", ci_steps(base: nil).assoc("Gate: Mutation").last
    assert_equal "bin/mutant-floor origin/main", ci_steps(base: "").assoc("Gate: Mutation").last
  end

  # --- The mutation gate --------------------------------------------------------

  def coverage(diff, killed: false, timeout: false, abort: false, type: "evil", id: "evil:X")
    { "criteria_result" => { "process_abort" => abort, "test_result" => killed, "timeout" => timeout },
      "mutation_result" => { "mutation_type" => type, "mutation_diff" => diff, "mutation_identification" => id } }
  end

  def session(subjects, amounts = {})
    { "subject_results" => subjects.map do |name, coverages|
      { "expression_syntax" => name, "amount_mutations" => amounts.fetch(name, coverages.size), "coverage_results" => coverages }
    end }
  end

  def baseline(survivors) = { "anchors" => [ { "reason" => "accepted" } ], "survivors" => survivors }

  # The base defaults to the tip's subjects with nothing alive, all selected by the base's own config.
  def compare(tip, base = session(MutantFloor.subjects(tip).to_h { |name| [ name, [] ] }), base_selected: MutantFloor.subjects(base),
              expressions: [ "Home*", "Pages*" ], defined_as: {}, accepted: {})
    MutantFloor.compare(tip, base, base_selected:, expressions:, defined_as:, accepted:)
  end

  def config_entry(**fields) = { "reason" => "a reason" }.merge(fields.transform_keys(&:to_s))

  DROP_ORDER = "@@ -1,4 +1,4 @@\n def show\n-  @sections = all.ordered\n+  @sections = all\n end\n"
  DROP_LIMIT = "@@ -1,4 +1,4 @@\n def show\n-  @posts = recent.limit(3)\n+  @posts = recent\n end\n"

  test "CI-4 a survivor the base has too passes, wherever its method has moved and whatever else it holds" do
    moved = "@@ -3,6 +3,6 @@\n def show\n   log\n-  @sections = all.ordered\n+  @sections = all\n   @posts = recent\n end\n"
    neutral = coverage(nil, killed: true, type: "neutral") # mutant's run of the code as written: no diff
    verdict = compare(session("Home#show" => [ neutral, coverage(moved) ], "Pages#show" => []),
                      session("Home#show" => [ neutral, coverage(DROP_ORDER) ], "Pages#show" => []))

    assert verdict.pass?
    assert_empty verdict.new_survivors
  end

  test "CI-4 a survivor the base doesn't have fails, and is named" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, id: "evil:Home#show:1:abc") ], "Pages#show" => []),
                      session("Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => []))

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", "-  @sections = all.ordered\n+  @sections = all", "evil:Home#show:1:abc" ] ],
                 verdict.new_survivors.map { |s| [ s.subject, s.change, s.identification ] }
  end

  test "CI-4 the same change in another subject is a different survivor" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [ coverage(DROP_ORDER) ]),
                      session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => []))

    assert_equal [ "Pages#show" ], verdict.new_survivors.map(&:subject)
  end

  test "CI-4 survivors are counted per key: a second copy of one the base has fails" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_ORDER) ], "Pages#show" => []),
                      session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => []))

    assert_equal 1, verdict.new_survivors.size
  end

  test "CI-4 a test that now kills a survivor the base has passes, with nothing to re-record" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => []),
                      session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => []))

    assert verdict.pass?
    assert_empty verdict.timed_out
  end

  test "CI-4 a subject the base's own config didn't select counts no survivors at the base" do
    tip = session("Home#show" => [], "Pages#show" => [ coverage(DROP_ORDER) ])
    base = session("Home#show" => [], "Pages#show" => [ coverage(DROP_ORDER) ]) # the tip's config, run on the base

    assert compare(tip, base).pass?
    assert_equal [ "Pages#show" ], compare(tip, base, base_selected: [ "Home#show" ]).new_survivors.map(&:subject)
  end

  test "CI-4 the step judges the base by its own selection, not by what the base run ran" do
    tip = session("Home#show" => [], "Pages#show" => [ coverage(DROP_ORDER) ])
    base = session("Home#show" => [], "Pages#show" => [ coverage(DROP_ORDER) ])
    config = { "matcher" => { "subjects" => [ "Home*", "Pages*" ] } }
    listing = "Subjects in environment: 1\nHome#show\n" # what mutant lists at the base, under the base's own config
    verdict = MutantFloor.judge(tip:, base:, listing:, config:, accepted: {}, defined_as: {}, reasoned: [])

    assert_not verdict.pass?
    assert_equal [ "Pages#show" ], verdict.new_survivors.map(&:subject)
    gone = MutantFloor.judge(tip:, base:, listing:, accepted: {}, defined_as: {}, reasoned: [],
                             config: { "matcher" => { "subjects" => [ "Home*", "Pages#gone" ] } })
    assert_equal [ "Pages#gone" ], gone.unmatched, "the expressions are the change's config's"
    assert_equal [ "Home#index" ], MutantFloor.missing(tip, "Subjects in environment: 3\nHome#show\nHome#index\nPages#show\n")
    assert_equal [ "Pages#show" ], MutantFloor.judge(tip:, base:, listing: nil, config:, accepted: {}, defined_as: {}, reasoned: [])
                                              .new_survivors.map(&:subject), "a base without config/mutant.yml selects nothing"
    assert_raises(ArgumentError) { MutantFloor.judge(tip:, base:, listing: MutantFloor.subjects(base), config:, accepted: {}, defined_as: {}, reasoned: []) }
  end

  test "CI-4 a neutral mutation that fails, aborts or times out fails" do
    [ { killed: false }, { killed: true, abort: true }, { killed: false, timeout: true }, { killed: true, timeout: true } ].each do |outcome|
      verdict = compare(session("Home#show" => [ coverage(nil, type: "neutral", **outcome) ], "Pages#show" => []))

      assert_not verdict.pass?, outcome.inspect
      assert_equal [ "Home#show" ], verdict.broken.map(&:subject), outcome.inspect
    end
    assert compare(session("Home#show" => [ coverage(nil, type: "neutral", killed: true) ], "Pages#show" => [])).pass?
  end

  test "CI-4 a subject with fewer results than mutations fails" do
    verdict = compare(session({ "Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => [] }, { "Home#show" => 2 }))

    assert_not verdict.pass?
    assert_equal [ "Home#show" ], verdict.partial
  end

  test "CI-4 an expression in config/mutant.yml that matches no subject fails" do
    verdict = compare(session("Home#show" => [], "Pages#show" => []), expressions: [ "Home*", "Pages#show", "Gone*", "Pages#gone" ])

    assert_not verdict.pass?
    assert_equal [ "Gone*", "Pages#gone" ], verdict.unmatched
  end

  test "CI-4 an expression matches its namespace and what it nests, not a longer name" do
    subjects = session("Home#show" => [], "Home::Card.build" => [], "Homepage#show" => [])

    assert_empty compare(subjects, expressions: [ "Home*", "Homepage#show" ]).unmatched
    assert_equal [ "Home::Card*" ], compare(session("Homepage#show" => []), expressions: [ "Home::Card*" ]).unmatched
    assert_equal [ "Hom*" ], compare(subjects, expressions: [ "Hom*" ]).unmatched
  end

  test "CI-4 a method the change still defines that no subject runs fails, naming where it lives" do
    base = session("Home#show" => [], "Home#index" => [], "Pages#show" => [])
    tip = session("Home#show" => [], "Pages#show" => [])

    # redefined with define_method; moved into a concern no subject selects; extracted into a service, beside a copy a subject runs
    [ [ "Home#index" ], [ "Listing#index" ], [ "Pages#show", "Listing#index" ] ].each do |now|
      verdict = compare(tip, base, defined_as: { "Home#index" => now })
      assert_not verdict.pass?, now.inspect
      assert_equal [ [ "Home#index", now - [ "Pages#show" ] ] ], verdict.left, now.inspect
    end
    assert_equal [ [ "Home#index", [ "Home#index" ] ] ], compare(tip, base).left, "a subject nobody looked up counts as still defined"
  end

  test "CI-4 a method the change no longer defines fails as removed, unless its own class gained a subject" do
    base = session("Home#show" => [], "Home#index" => [], "Pages#show" => [])

    removed = compare(session("Home#show" => [], "Pages#show" => []), base, defined_as: { "Home#index" => [] })
    assert_not removed.pass?, "Home#show ran at the base too, so it isn't a new name"
    assert_equal [ [ "Home#index", [] ] ], removed.removed
    assert_empty removed.moved

    # extracted under a new name into another class, selected or not
    elsewhere = compare(session("Home#show" => [], "Pages#show" => [], "Listing#list" => []), base,
                        defined_as: { "Home#index" => [] }, expressions: [ "Home*", "Pages*", "Listing*" ])
    assert_equal [ [ "Home#index", [] ] ], elsewhere.removed

    renamed = compare(session("Home#show" => [], "Home#list" => [], "Home.build" => [], "Pages#show" => []), base, defined_as: { "Home#index" => [] })
    assert renamed.pass?
    assert_equal [ [ "Home#index", [ "Home#list" ] ] ], renamed.renamed
    assert_empty renamed.removed
    nested = compare(session("Home#show" => [], "Home::Card#list" => [], "Pages#show" => []), base, defined_as: { "Home#index" => [] })
    assert_equal [ [ "Home#index", [] ] ], nested.removed, "a nested constant is another class"
  end

  test "CI-4 each new subject stands for one vanished subject of its class: the same name first, then in name order" do
    base = session("Home#show" => [], "Home#index" => [], "Home#list" => [], "Home.build" => [], "Pages#show" => [])
    gone = { "Home#index" => [], "Home#list" => [], "Home.build" => [] }
    tip = ->(*arrived) { session(([ "Home#show", "Pages#show" ] + arrived).to_h { |name| [ name, [] ] }) }

    delegator = compare(tip.("Home#locale"), base, defined_as: gone) # an extraction that leaves one delegator behind
    assert_not delegator.pass?
    assert_equal [ [ "Home#index", [ "Home#locale" ] ] ], delegator.renamed
    assert_equal [ [ "Home#list", [] ], [ "Home.build", [] ] ], delegator.removed

    exact = compare(tip.("Home#aaa", "Home#build"), base, defined_as: gone)
    assert_equal [ [ "Home#index", [ "Home#aaa" ] ], [ "Home.build", [ "Home#build" ] ] ], exact.renamed
    assert_equal [ [ "Home#list", [] ] ], exact.removed
    assert compare(tip.("Home#a", "Home#b", "Home#c"), base, defined_as: gone).pass?
  end

  test "CI-4 a method moved where a subject runs it passes, and is reported" do
    base = session("Home#show" => [], "Home#index" => [], "Pages#show" => [])
    moved = compare(session("Home#show" => [], "Pages#show" => [], "Listing#index" => []), base,
                    defined_as: { "Home#index" => [ "Listing#index" ] }, expressions: [ "Home*", "Pages*", "Listing*" ])

    assert moved.pass?
    assert_equal [ [ "Home#index", [ "Listing#index" ] ] ], moved.moved
  end

  test "CI-4 a survivor carried across a rename or move passes one for one, and is reported" do
    base = session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_LIMIT) ], "Pages#show" => [])
    expressions = [ "Pages*", "Listing*" ]
    moved = ->(*coverages) { session("Listing#show" => coverages, "Pages#show" => []) }

    verdict = compare(moved.(coverage(DROP_ORDER), coverage(DROP_LIMIT)), base, defined_as: { "Home#show" => [ "Listing#show" ] }, expressions:)
    assert verdict.pass?
    assert_equal [ [ "Home#show", "Listing#show", MutantFloor.change(DROP_ORDER) ], [ "Home#show", "Listing#show", MutantFloor.change(DROP_LIMIT) ] ],
                 verdict.carried

    twice = compare(moved.(coverage(DROP_ORDER), coverage(DROP_ORDER)), base, defined_as: { "Home#show" => [ "Listing#show" ] }, expressions:)
    assert_equal [ [ "Listing#show", MutantFloor.change(DROP_ORDER) ] ], twice.new_survivors.map { |s| [ s.subject, s.change ] }
  end

  test "CI-4 a base with two copies of a survivor carries two, and no more" do
    base = session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_ORDER) ], "Pages#show" => [])
    moved = ->(copies) { session("Listing#show" => [ coverage(DROP_ORDER) ] * copies, "Pages#show" => []) }
    judge = ->(copies) { compare(moved.(copies), base, defined_as: { "Home#show" => [ "Listing#show" ] }, expressions: [ "Pages*", "Listing*" ]) }

    assert_equal 2, judge.(2).carried.size
    assert judge.(2).pass?
    assert_equal 1, judge.(3).new_survivors.size
  end

  test "CI-4 a survivor of a deleted method doesn't carry into a subject that ran at both" do
    base = session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [])
    tip = session("Pages#show" => [ coverage(DROP_ORDER) ])
    verdict = compare(tip, base, defined_as: { "Home#show" => [] }, expressions: [ "Pages*" ])

    assert_empty verdict.carried
    assert_equal [ "Pages#show" ], verdict.new_survivors.map(&:subject)
  end

  test "CI-4 a new subject doesn't carry from a subject that still runs" do
    base = session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [])
    tip = session("Home#show" => [ coverage(DROP_ORDER, killed: true) ], "Pages#show" => [], "Listing#show" => [ coverage(DROP_ORDER) ])
    verdict = compare(tip, base, expressions: [ "Home*", "Pages*", "Listing*" ])

    assert_empty verdict.carried
    assert_equal [ "Listing#show" ], verdict.new_survivors.map(&:subject)
  end

  test "CI-4 a mutation alive at the base and killed only by a timeout passes, and is reported" do
    base = session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [])
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, timeout: true) ], "Pages#show" => []), base)

    assert verdict.pass?
    assert_equal [ [ "Home#show", MutantFloor.change(DROP_ORDER) ] ], verdict.timed_out
    assert_empty compare(session("Home#show" => [ coverage(DROP_ORDER, killed: true, timeout: true) ], "Pages#show" => []), base).timed_out,
                 "a test kill is not a timeout-only kill"
  end

  test "CI-4 each outcome that passes prints its line" do
    base = session("Home#show" => [ coverage(DROP_ORDER) ], "Home#index" => [], "Home#list" => [], "Pages#show" => [ coverage(DROP_LIMIT) ])
    tip = session("Listing#show" => [ coverage(DROP_ORDER) ], "Pages#show" => [ coverage(DROP_LIMIT, timeout: true) ], "Listing#index" => [],
                  "Home#listing" => [])
    verdict = compare(tip, base, expressions: [ "Home*", "Pages*", "Listing*" ],
                                 defined_as: { "Home#show" => [ "Listing#show" ], "Home#index" => [ "Listing#index" ], "Home#list" => [] })
    lines = MutantFloor.report(verdict)

    assert verdict.pass?
    assert_includes lines, "  survivor of Home#show carried to Listing#show"
    assert_includes lines, "  Home#list is no longer defined; renamed in place, beside Home#listing"
    assert_includes lines, "  Home#index now runs as Listing#index"
    assert_includes lines, "Killed only by a timeout, so tolerated (a slow runner can do this):"
    assert_includes lines, "  Pages#show"
    assert_includes lines, "    -  @posts = recent.limit(3)"
  end

  test "CI-4 each failure prints its line, naming where a method that left now lives" do
    verdict = compare(session("Home#show" => [ coverage(DROP_ORDER, id: "evil:1") ], "Pages#show" => []),
                      session("Home#show" => [], "Home#index" => [], "Pages#show" => []),
                      defined_as: { "Home#index" => [ "LocaleNegotiator#index" ] }, expressions: [ "Home*", "Pages*", "Gone*" ])
    lines = MutantFloor.report(verdict)

    assert_includes lines, "FAIL: still defined, but no subject runs them any more (select where they live in config/mutant.yml):"
    assert_includes lines, "  Home#index, now in LocaleNegotiator#index"
    assert_includes MutantFloor.report(compare(session("Home#show" => [], "Pages#show" => []), session("Home#show" => [], "Home#index" => [], "Pages#show" => []))),
                    "  Home#index, still there but out of mutant's reach (define_method, or patched in from config/)"
    assert_includes lines, "FAIL: named in config/mutant.yml, but no such subject ran:"
    assert_includes lines, "  Gone*"
    removed = MutantFloor.report(compare(session("Home#show" => [], "Pages#show" => []), session("Home#show" => [], "Home#index" => [], "Pages#show" => []),
                                         defined_as: { "Home#index" => [] }))
    assert_includes removed, "FAIL: removed or renamed out of mutation's reach; add a `subjects:` entry to test/mutant/accepted.yml with the reason if it was deleted:"
    assert_includes removed, "  Home#index"
    assert_includes lines, "FAIL: 1 survivor(s) the base doesn't have:"
    assert_includes lines, "  Home#show  evil:1"
  end

  test "CI-4 a base run that is incomplete, or whose neutral fails, is a gap at the base" do
    assert_empty MutantFloor.base_gap(session("Home#show" => [ coverage(nil, type: "neutral", killed: true), coverage(DROP_ORDER) ]))

    partial = MutantFloor.base_gap(session({ "Home#show" => [] }, { "Home#show" => 3 }))
    broken = MutantFloor.base_gap(session("Home#show" => [ coverage(nil, type: "neutral", timeout: true) ]))
    assert_equal [ "Home#show: fewer results than mutations" ], partial
    assert_equal [ "Home#show: the tests fail on the code as written" ], broken
  end

  test "CI-4 a gap at the base names its first error, and points at the bundle or harness when the change touched them" do
    output = "warning: parser/current is loading parser/ruby33\n" \
             "/gems/bootsnap/load_path_cache.rb:30:in 'require': cannot load such file -- rouge (LoadError)\n" \
             "\tfrom /gems/mutant/segment/recorder.rb:22:in 'record'\n"
    plain = MutantFloor.gap_lines("abc1234", "mutant could not list its subjects", output:, changed: [ "app/models/post.rb" ])
    bundle = %w[Gemfile Gemfile.lock tools/Gemfile.lock test/mutant/boot.rb test/mutant/hooks.rb config/mutant.yml].map do |path|
      MutantFloor.gap_lines("abc1234", "mutant could not list its subjects", output:, changed: [ path ]).last
    end

    assert_equal "mutant-floor: GAP AT THE BASE (abc1234): mutant could not list its subjects", plain.first
    assert_includes plain, "  /gems/bootsnap/load_path_cache.rb:30:in 'require': cannot load such file -- rouge (LoadError)"
    assert_equal "mutant-floor: this is the base's run failing, not a finding against the change", plain.last
    assert_equal [ "mutant-floor: the base can't run under this change's bundle or harness; land the code change separately" ], bundle.uniq
  end

  test "CI-4 the base's own selection is read from mutant's subject list, and a list it can't read is a gap" do
    listing = "warning: parser/current is loading parser/ruby33\nSubjects in environment: 12\n#{(1..12).map { |n| "Home#a#{n}\n" }.join}"

    assert_equal 12, MutantFloor.selection(listing).size
    assert_equal [ "Home#show", "Pages#show" ], MutantFloor.selection("Subjects in environment: 2\nHome#show\nPages#show\n")
    assert_nil MutantFloor.selection("Subjects in environment: 3\nHome#show\nPages#show\n")
    assert_nil MutantFloor.selection("LoadError: cannot load such file\n")
  end

  test "CI-4 the base runs from its own tree with the change's harness, bundle and one seed" do
    assert_equal %w[config/mutant.yml test/mutant/boot.rb test/mutant/hooks.rb], MutantFloor::HARNESS
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "test/mutant"))
      File.write(File.join(dir, "test/mutant/boot.rb"), "# the base's own\n")
      MutantFloor.copy_harness(from: Rails.root.to_s, to: dir)

      MutantFloor::HARNESS.each { |path| assert_equal Rails.root.join(path).read, File.read(File.join(dir, path)), path }
    end

    env = MutantFloor.base_env(Rails.root.to_s)
    assert_equal [ Rails.root.join("Gemfile").to_s, Rails.root.join("Gemfile.lock").to_s, "test" ], env.values_at("BUNDLE_GEMFILE", "BUNDLE_LOCKFILE", "RAILS_ENV")
    assert env.key?("RUBYOPT") && env["RUBYOPT"].nil?, "RUBYOPT is cleared, not inherited"
    assert_match(/^\s*::Minitest\.seed = 0\b/, Rails.root.join("test/mutant/boot.rb").read)
    assert_no_match(/random/, Rails.root.join("test/mutant/boot.rb").read)
  end

  test "CI-4 bin/mutant-floor wires its checks end to end, on stand-ins for mutant and Rails" do
    Dir.mktmpdir do |dir|
      %w[bin/mutant-floor test/mutant/floor.rb test/mutant/boot.rb test/mutant/hooks.rb test/mutant/baseline.yml].each do |path|
        FileUtils.mkdir_p(File.join(dir, File.dirname(path)))
        FileUtils.cp(Rails.root.join(path), File.join(dir, path))
      end
      FileUtils.mkdir_p([ "#{dir}/config", "#{dir}/stand-in" ])
      File.write("#{dir}/config/mutant.yml", YAML.dump("matcher" => { "subjects" => [ "Home*" ] }))
      File.write("#{dir}/stand-in/session.json", JSON.dump(session("Home#show" => [ coverage(DROP_ORDER) ])))
      File.write("#{dir}/bin/rails", "#!/bin/sh\n")
      File.write("#{dir}/stand-in/bundle", <<~SH) # `bundle exec mutant run` writes a session; `... subject list` lists it
        #!/bin/sh
        if [ "$3" = run ]; then mkdir -p .mutant/results && cp #{dir}/stand-in/session.json .mutant/results/$$.json
        else printf 'Subjects in environment: 1\nHome#show\n'; fi
      SH
      FileUtils.chmod(0o755, [ "#{dir}/bin/rails", "#{dir}/stand-in/bundle" ])
      git = ->(*args) { assert system("git", "-c", "user.name=ci", "-c", "user.email=ci@example.invalid", *args, chdir: dir, out: File::NULL, err: File::NULL), args.join(" ") }
      git.("init", "-q") && git.("add", "-A") && git.("commit", "-qm", "base")
      File.write("#{dir}/test/mutant/boot.rb", "# changed\n", mode: "a")
      File.write("#{dir}/test/mutant/accepted.yml", YAML.dump("config" => [ config_entry(change: "harness", reason: "The seed is fixed.") ]))
      git.("add", "-A") && git.("commit", "-qm", "change")

      out, status = Open3.capture2e({ "PATH" => "#{dir}/stand-in:#{ENV["PATH"]}" }, "ruby", "bin/mutant-floor", "HEAD~1", chdir: dir)
      assert status.success?, out
      assert_includes out, "  change: harness, for test/mutant/boot.rb\n    The seed is fixed.\n", "the base's harness is read from git"
      assert_includes out, "mutant-floor: no survivor the base doesn't have", "the base's survivor is counted under its own selection"
    end
  end

  # Stand-ins for app code, to look up the way the gate looks up a subject the tip no longer runs.
  module Probe
    module Moved
      private def switch = nil
    end

    class Host
      include Moved
      def kept = nil
      define_method(:made) { nil }
      def self.build = nil
    end

    class Elsewhere
      def probe_extracted = nil
      def self.probe_class_level = nil
      private def probe_hidden = nil
    end
  end

  test "CI-4 a subject is looked up by its current owner, in the app's own files only" do
    here = [ __dir__ ]
    prefix = "CiContractTest::Probe"

    assert_equal [ "#{prefix}::Host#kept" ], MutantFloor.defined_as("#{prefix}::Host#kept", paths: here)
    assert_equal [ "#{prefix}::Moved#switch" ], MutantFloor.defined_as("#{prefix}::Host#switch", paths: here)
    assert_equal [ "#{prefix}::Host#made" ], MutantFloor.defined_as("#{prefix}::Host#made", paths: here)
    assert_equal [ "#{prefix}::Host.build" ], MutantFloor.defined_as("#{prefix}::Host.build", paths: here)
    assert_empty MutantFloor.defined_as("#{prefix}::Host#probe_never_defined", paths: here), "renamed or deleted"
    assert_empty MutantFloor.defined_as("#{prefix}::Host#to_s", paths: here), "inherited from Object"
    assert_empty MutantFloor.defined_as("#{prefix}::Host#kept", paths: [ Rails.root.join("app").to_s ]), "outside the app's files"
  end

  test "CI-4 a method moved out of its class is found wherever the app defines one by that name and kind" do
    here = [ __dir__ ]
    prefix = "CiContractTest::Probe"

    assert_equal [ "#{prefix}::Elsewhere#probe_extracted" ], MutantFloor.defined_as("#{prefix}::Host#probe_extracted", paths: here)
    assert_equal [ "#{prefix}::Elsewhere#probe_hidden" ], MutantFloor.defined_as("#{prefix}::Host#probe_hidden", paths: here)
    assert_equal [ "#{prefix}::Elsewhere#probe_extracted" ], MutantFloor.defined_as("#{prefix}::Gone#probe_extracted", paths: here),
                 "its old class may be gone too"
    assert_equal [ "#{prefix}::Elsewhere.probe_class_level" ], MutantFloor.defined_as("#{prefix}::Host.probe_class_level", paths: here)
    assert_empty MutantFloor.defined_as("#{prefix}::Host#probe_class_level", paths: here), "a singleton method is not an instance one"
    assert_empty MutantFloor.defined_as("#{prefix}::Host.probe_extracted", paths: here), "an instance method is not a singleton one"
    assert_empty MutantFloor.defined_as("#{prefix}::Host#probe_extracted", paths: [ Rails.root.join("app").to_s ])
  end

  test "CI-4 the step looks a subject up in the app's app/, lib/ and config/, and reads back what it found" do
    Dir.mktmpdir do |root|
      %w[app lib config test].each do |dir|
        FileUtils.mkdir_p(File.join(root, dir))
        File.write(File.join(root, dir, "probe.rb"), "class CiContractTest::Probe::Loaded; def probe_in_#{dir} = nil; end\n")
        load File.join(root, dir, "probe.rb")
      end
      subjects = %w[app lib config test].map { |dir| "CiContractTest::Probe::Gone#probe_in_#{dir}" }
      found = MutantFloor.looked_up("noise\n#{MutantFloor.lookup(subjects, root:).join("\n")}\n")

      assert_equal %w[app lib config].to_h { |dir| [ "CiContractTest::Probe::Gone#probe_in_#{dir}", [ "CiContractTest::Probe::Loaded#probe_in_#{dir}" ] ] }
                     .merge("CiContractTest::Probe::Gone#probe_in_test" => []), found
    end
  end

  EQUIVALENT = { "subject" => "Home#show", "change" => "-  @sections = all.ordered\n+  @sections = all", "reason" => "SQLite reads them in index order" }

  test "CI-5 an equivalent the change adds accepts one new survivor, which is reported" do
    tip = session("Home#show" => [ coverage(DROP_ORDER), coverage(DROP_ORDER) ], "Pages#show" => [])
    verdict = compare(tip, accepted: { "equivalents" => [ EQUIVALENT ] })

    assert_equal [ "Home#show" ], verdict.equivalent.map(&:subject)
    assert_equal [ "Home#show" ], verdict.new_survivors.map(&:subject)
    assert_includes MutantFloor.report(verdict), "Accepted as equivalent by test/mutant/accepted.yml:"
    assert compare(session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => []), accepted: { "equivalents" => [ EQUIVALENT ] }).pass?
  end

  test "CI-5 an equivalent matches whatever trailing whitespace either side has" do
    kept_newline = EQUIVALENT.merge("change" => "#{EQUIVALENT["change"]}  \n") # YAML's | rather than |-
    padded = "@@ -1,4 +1,4 @@\n def show\n-  @sections = all.ordered \n+  @sections = all\n end\n"

    assert compare(session("Home#show" => [ coverage(DROP_ORDER) ], "Pages#show" => []), accepted: { "equivalents" => [ kept_newline ] }).pass?
    assert compare(session("Home#show" => [ coverage(padded) ], "Pages#show" => []), accepted: { "equivalents" => [ EQUIVALENT ] }).pass?
  end

  test "CI-5 an equivalent that matches no new survivor fails" do
    verdict = compare(session("Home#show" => [], "Pages#show" => []), accepted: { "equivalents" => [ EQUIVALENT ] })

    assert_not verdict.pass?
    assert_equal [ [ "Home#show", EQUIVALENT["change"] ] ], verdict.unused
  end

  test "CI-5 accepted.yml is append-only: only what follows the base's entries counts" do
    old = EQUIVALENT.merge("reason" => "accepted long ago")
    added, problems = MutantFloor.accepted({ "equivalents" => [ old, EQUIVALENT ], "config" => [] }, { "equivalents" => [ old ], "config" => [] })
    assert_empty problems
    assert_equal({ "equivalents" => [ EQUIVALENT ], "config" => [] }, added)

    copy, = MutantFloor.accepted({ "equivalents" => [ old, old ] }, { "equivalents" => [ old ] })
    assert_equal [ old ], copy["equivalents"], "a second copy is a new entry"

    reworded = config_entry(subjects: [ "Pages#consulting" ], reason: "it returns")
    _, edited = MutantFloor.accepted({ "config" => [ reworded, config_entry(change: "config") ] }, { "config" => [ reworded.merge("reason" => "it comes back") ] })
    assert_equal [ "test/mutant/accepted.yml edits or removes an existing config entry; append instead" ], edited
    _, removed = MutantFloor.accepted({ "equivalents" => [] }, { "equivalents" => [ old ] })
    assert_equal [ "test/mutant/accepted.yml edits or removes an existing equivalents entry; append instead" ], removed
  end

  test "CI-5 an entry accepted.yml adds of the wrong shape, or without a reason, fails with a message" do
    entries = {
      "equivalents" => [ "a reason", EQUIVALENT.except("change"), EQUIVALENT.merge("reason" => " ") ],
      "config" => [ config_entry(change: "everything"), config_entry(subjects: "Home#show"), config_entry(subjects: [ "Home#show" ], change: "config"),
                    { "change" => "config" } ]
    }
    _, problems = MutantFloor.accepted(entries, {})

    assert_equal 7, problems.size, problems.join("\n")
    assert problems.all? { |problem| problem.start_with?("an entry test/mutant/accepted.yml adds under ") }, problems.join("\n")
    _, list = MutantFloor.accepted({ "equivalents" => "Home#show" }, {})
    assert_equal [ "test/mutant/accepted.yml: equivalents must be a list" ], list
    assert_empty MutantFloor.accepted({ "config" => [ config_entry(subjects: [ "Home#show" ]), config_entry(change: "harness") ] }, nil).last
    assert_equal [ "test/mutant/accepted.yml must be a mapping of equivalents and config" ], MutantFloor.accepted([ EQUIVALENT ], nil).last
  end

  test "CI-5 a file the gate reads that isn't valid YAML fails with a message" do
    document, problem = MutantFloor.parse_yaml("config:\n  - change: harness\n    reason: slow (a note: here)\n", "test/mutant/accepted.yml")

    assert_nil document
    assert_match(/\Atest\/mutant\/accepted\.yml is not valid YAML: .*mapping values are not allowed/, problem)
    assert_equal [ { "config" => [] }, nil ], MutantFloor.parse_yaml("config: []\n", "x.yml")
    assert_equal [ {}, nil ], MutantFloor.parse_yaml("", "x.yml")
    assert_equal [ nil, nil ], MutantFloor.parse_yaml(nil, "x.yml"), "a file that doesn't exist is no problem"
  end

  test "CI-5 narrowing config/mutant.yml for a method the change still defines fails, unless a config entry names it" do
    base = session("Home#show" => [], "Home#index" => [], "Pages#show" => [])
    tip = session("Pages#show" => []) # e.g. Home* narrowed or ignored, so the base run under the tip's config skips them
    narrow = ->(**accepted) { compare(tip, session("Pages#show" => []), base_selected: MutantFloor.subjects(base), expressions: [ "Pages*" ], accepted: accepted.transform_keys(&:to_s)) }

    assert_equal [ [ "Home#show", [ "Home#show" ] ], [ "Home#index", [ "Home#index" ] ] ], narrow.().deselected
    named = narrow.(config: [ config_entry(subjects: [ "Home#show" ]) ])
    assert_equal [ [ "Home#index", [ "Home#index" ] ] ], named.deselected, "an entry excuses only the subjects it names"
    assert_equal [ [ "Home#show", [ "Home#show" ] ] ], named.excused
    assert_includes MutantFloor.report(named), "No longer mutated, excused by a config entry in test/mutant/accepted.yml:"
    assert_equal 2, narrow.(config: [ config_entry(change: "config") ]).deselected.size, "change: config excuses no subject"
    assert_equal 2, narrow.(equivalents: [ EQUIVALENT ]).deselected.size, "an equivalent excuses no subject"
    assert narrow.(config: [ config_entry(subjects: [ "Home#show", "Home#index" ]) ]).pass?

    deleted = ->(**accepted) do
      compare(tip, session("Pages#show" => []), base_selected: MutantFloor.subjects(base), expressions: [ "Pages*" ],
              defined_as: { "Home#show" => [], "Home#index" => [] }, accepted: accepted.transform_keys(&:to_s))
    end
    assert_equal [ [ "Home#show", [] ], [ "Home#index", [] ] ], deleted.().removed, "a deleted method's expression goes with a reason"
    assert deleted.(config: [ config_entry(subjects: [ "Home#show", "Home#index" ]) ]).pass?
  end

  test "CI-5 a config entry naming a removed subject excuses it, and only it, and is reported" do
    base = session("Home#show" => [], "Home#index" => [], "Home#list" => [], "Pages#show" => [])
    tip = session("Home#show" => [], "Pages#show" => [])
    verdict = compare(tip, base, defined_as: { "Home#index" => [], "Home#list" => [] }, accepted: { "config" => [ config_entry(subjects: [ "Home#index" ]) ] })

    assert_equal [ [ "Home#index", [] ] ], verdict.excused
    assert_equal [ [ "Home#list", [] ] ], verdict.removed
    assert_includes MutantFloor.report(verdict), "  Home#index, removed"
    assert compare(tip, base, defined_as: { "Home#index" => [], "Home#list" => [] },
                              accepted: { "config" => [ config_entry(subjects: [ "Home#index", "Home#list" ]) ] }).pass?
  end

  test "CI-5 a config entry naming a subject that left the selection excuses it" do
    base = session("Home#show" => [], "Home#index" => [], "Pages#show" => [])
    tip = session("Home#show" => [], "Pages#show" => [])
    verdict = compare(tip, base, defined_as: { "Home#index" => [ "Home#index" ] }, accepted: { "config" => [ config_entry(subjects: [ "Home#index" ]) ] })

    assert verdict.pass? # e.g. `def index` became `attr_reader :index`
    assert_equal [ [ "Home#index", [ "Home#index" ] ] ], verdict.excused
  end

  def weakened(config, base_config, head = HARNESS_TEXT, base = HARNESS_TEXT) = MutantFloor.weakenings(config, base_config, head, base)

  HARNESS_TEXT = %w[test/mutant/boot.rb test/mutant/hooks.rb].to_h { |path| [ path, Rails.root.join(path).read ] }

  test "CI-5 a change to config/mutant.yml outside its subjects and ignores fails, unless a change: config entry gives the reason" do
    base = YAML.load_file(Rails.root.join("config/mutant.yml"))
    added = base.merge("matcher" => base["matcher"].merge("subjects" => base.dig("matcher", "subjects") + [ "PostsController*" ],
                                                         "ignore" => [ "HomeController#show" ]))
    slower = base.merge("mutation" => { "timeout" => 0.01 })
    lighter = base.merge("mutation" => { "operators" => "light" })
    started = base.merge("matcher" => base["matcher"].merge("start_expressions" => [ "Home*" ]))
    problems = ->(config, entries = []) { MutantFloor.reasoned(weakened(config, base), entries).first }

    assert_empty weakened(base, base)
    assert_empty weakened(added, base), "subjects and ignores are judged by what they select"
    [ slower, lighter, started, base.except("hooks") ].each do |changed|
      assert_equal [ "config/mutant.yml changes outside its subjects and ignores; add a `change: config` entry to test/mutant/accepted.yml with the reason" ],
                   problems.(changed), changed.inspect
    end
    assert_empty problems.(lighter, [ config_entry(change: "config") ])
    assert_equal 1, problems.(lighter, [ config_entry(change: "harness") ]).size
    assert_equal 1, problems.(lighter, [ config_entry(subjects: [ "Home#show" ]) ]).size
    assert_empty weakened(base, nil)
  end

  test "CI-5 a change to boot.rb or hooks.rb fails, unless a change: harness entry gives the reason" do
    weaker = HARNESS_TEXT.merge("test/mutant/boot.rb" => HARNESS_TEXT["test/mutant/boot.rb"].sub(".select {", ".reject { |path| path.read.include?(\"IntegrationTest\") }.select {"))
    config = YAML.load_file(Rails.root.join("config/mutant.yml"))
    problems = ->(head, entries = []) { MutantFloor.reasoned(weakened(config, config, head), entries).first }

    assert_empty weakened(config, config)
    assert_equal [ "test/mutant/boot.rb changes; add a `change: harness` entry to test/mutant/accepted.yml with the reason" ], problems.(weaker)
    assert_equal [ "test/mutant/hooks.rb changes; add a `change: harness` entry to test/mutant/accepted.yml with the reason" ],
                 problems.(HARNESS_TEXT.merge("test/mutant/hooks.rb" => ""))
    assert_equal({ "harness" => %w[test/mutant/boot.rb test/mutant/hooks.rb] },
                 weakened(config, config, HARNESS_TEXT.transform_values { "" }), "the step compares both files")
    assert_equal 1, problems.(weaker, [ config_entry(change: "config") ]).size
    assert_empty problems.(weaker, [ config_entry(change: "harness") ])
    assert_empty weakened(config, config, HARNESS_TEXT, HARNESS_TEXT.transform_values { nil }), "a base without a harness has nothing to weaken"
    assert_empty weakened(config, config, ->(path) { HARNESS_TEXT[path] }, ->(path) { HARNESS_TEXT[path] }), "either side may be read lazily"
  end

  test "CI-5 each change a change: entry accepts is reported with its files and reason" do
    config = YAML.load_file(Rails.root.join("config/mutant.yml"))
    changed = weakened(config.merge("mutation" => { "timeout" => 5 }), config, HARNESS_TEXT.merge("test/mutant/boot.rb" => "# seeded\n"))
    entries = [ config_entry(change: "harness", reason: "The seed is fixed at 0.\n"), config_entry(change: "config", reason: "A slower runner.") ]
    problems, reasoned = MutantFloor.reasoned(changed, entries)
    tip = session("Home#show" => [], "Pages#show" => [])
    verdict = MutantFloor.judge(tip:, base: tip, listing: "Subjects in environment: 2\nHome#show\nPages#show\n", config: { "matcher" => { "subjects" => [ "Home*", "Pages*" ] } },
                                accepted: {}, defined_as: {}, reasoned:)
    lines = MutantFloor.report(verdict)

    assert_empty problems
    assert verdict.pass?
    assert_includes lines, "Accepted by a change: entry in test/mutant/accepted.yml:"
    assert_includes lines, "  change: config, for config/mutant.yml"
    assert_includes lines, "    A slower runner."
    assert_includes lines, "  change: harness, for test/mutant/boot.rb"
    assert_includes lines, "    The seed is fixed at 0."
    assert_not_includes MutantFloor.report(compare(tip)), "Accepted by a change: entry in test/mutant/accepted.yml:"
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

  test "CI-6 exhale's bundle installs where its gems are missing, even from inside an app's bundle" do
    # Stand-ins for tools/ (one gem, cached locally, not yet installed) and for
    # the app on a fresh runner: a bundle with setup-ruby's vendor/bundle path,
    # which hands its children BUNDLER_SETUP and a GEM_HOME and GEM_PATH of its
    # own. The probe starts from inside it, as bin/ci's children do.
    Dir.mktmpdir do |dir|
      app, tools = File.join(dir, "app"), File.join(dir, "tools")
      FileUtils.mkdir_p([ File.join(app, ".bundle"), File.join(tools, ".bundle"), File.join(tools, "vendor/cache"), File.join(dir, "probe/lib") ])
      File.write(File.join(app, "Gemfile"), "")
      File.write(File.join(app, ".bundle/config"), "---\nBUNDLE_PATH: #{File.join(app, "vendor/bundle").dump}\n")

      File.write(File.join(dir, "probe/lib/probe.rb"), "Probe = :installed\n")
      File.write(File.join(dir, "probe/probe.gemspec"), <<~RUBY)
        Gem::Specification.new do |s|
          s.name, s.version, s.summary, s.authors, s.files = "probe", "0.1.0", "probe", [ "ci" ], [ "lib/probe.rb" ]
        end
      RUBY
      out, status = Bundler.with_unbundled_env { Open3.capture2e("gem", "build", "probe.gemspec", chdir: File.join(dir, "probe")) }
      assert status.success?, out
      FileUtils.mv(File.join(dir, "probe/probe-0.1.0.gem"), File.join(tools, "vendor/cache"))

      FileUtils.cp(Rails.root.join("tools/boot.rb"), tools)
      File.write(File.join(tools, "Gemfile"), "source \"https://rubygems.org\"\ngem \"probe\", \"0.1.0\"\n")
      File.write(File.join(tools, "Gemfile.lock"), <<~LOCK)
        GEM
          remote: https://rubygems.org/
          specs:
            probe (0.1.0)

        PLATFORMS
          ruby

        DEPENDENCIES
          probe (= 0.1.0)
      LOCK
      File.write(File.join(tools, ".bundle/config"), "---\nBUNDLE_PATH: #{File.join(tools, "bundle").dump}\n")
      File.write(File.join(tools, "probe.rb"), "require_relative \"boot\"\nrequire \"probe\"\nprint Probe\n")

      out, status = Bundler.with_unbundled_env do
        Open3.capture2e({ "BUNDLE_GEMFILE" => File.join(app, "Gemfile") }, "bundle", "exec", "ruby", File.join(tools, "probe.rb"))
      end
      assert status.success?, out
      assert_equal "installed", out.lines.last
    end
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
