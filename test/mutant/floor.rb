# The mutation gate (bin/mutant-floor): a run passes when the change leaves
# no mutation alive that its merge base didn't leave alive too. Both trees run
# every subject, and survivors are counted per key.
#
# A survivor is known by its subject and the lines its mutation removes and
# adds. Line numbers, file paths and the unchanged rest of the method are left
# out, so editing one method, or code above it, leaves every other survivor
# where it was.
require "fileutils"
require "json"
require "yaml"

module MutantFloor
  BASELINE = "test/mutant/baseline.yml"
  ACCEPTED = "test/mutant/accepted.yml"
  # Copied from the change into the base's tree, so both runs mutate alike.
  HARNESS = %w[config/mutant.yml test/mutant/boot.rb test/mutant/hooks.rb].freeze
  # The harness's code, compared byte for byte; config/mutant.yml has its own check.
  HARNESS_CODE = (HARNESS - [ "config/mutant.yml" ]).freeze
  # Where the app's own methods live, under its root; anything else is Rails's or a gem's.
  APP_PATHS = %w[app lib config].freeze
  # A change to these can leave the base unable to run under the change.
  BUNDLE = %r{\A(Gemfile|Gemfile\.lock|tools/|#{HARNESS.map { |path| Regexp.escape(path) }.join("|")})}

  Survivor = Data.define(:subject, :change, :identification)

  # The first eight fail the run; the rest are reported.
  Verdict = Data.define(:new_survivors, :unused, :broken, :partial, :unmatched, :left, :deselected, :removed,
                        :carried, :equivalent, :moved, :renamed, :excused, :timed_out, :reasoned) do
    def pass? = [ new_survivors, unused, broken, partial, unmatched, left, deselected, removed ].all?(&:empty?)
  end

  module_function

  # The lines a mutation diff removes and adds, which is all that identifies it.
  def change(diff)
    diff.to_s.lines.grep(/\A[-+]/).map(&:rstrip).join("\n")
  end

  # A change as written in accepted.yml, without the trailing whitespace YAML
  # or an editor leaves on it.
  def normal(change) = change.to_s.lines.map(&:rstrip).join("\n").rstrip

  # Every mutation result as [subject, change, coverage].
  def results(session)
    session.fetch("subject_results").flat_map do |subject|
      subject.fetch("coverage_results").map do |coverage|
        [ subject.fetch("expression_syntax"), change(coverage.dig("mutation_result", "mutation_diff")), coverage ]
      end
    end
  end

  def evil?(coverage) = coverage.dig("mutation_result", "mutation_type") == "evil"
  def uncovered?(coverage) = coverage.fetch("criteria_result").values.none?

  # Killed by nothing but a timeout.
  def timed_out?(coverage)
    criteria = coverage.fetch("criteria_result")
    criteria["timeout"] && !criteria["test_result"] && !criteria["process_abort"]
  end

  # A neutral (or noop) mutation is the code as written: its tests must pass,
  # in time, without the process aborting. mutant counts a timeout as success.
  def broken?(coverage)
    criteria = coverage.fetch("criteria_result")
    !evil?(coverage) && !(criteria["test_result"] && !criteria["timeout"] && !criteria["process_abort"])
  end

  def survivor(subject, change, coverage)
    Survivor.new(subject:, change:, identification: coverage.dig("mutation_result", "mutation_identification"))
  end

  # Survivors by [subject, change], optionally only for some subjects.
  def survivors(session, only: nil)
    results(session)
      .select { |subject, _, coverage| evil?(coverage) && uncovered?(coverage) && (only.nil? || only.include?(subject)) }
      .group_by { |subject, change, _| [ subject, change ] }
      .transform_values { |list| list.map { |subject, change, coverage| survivor(subject, change, coverage) } }
  end

  # Subjects a session ran.
  def subjects(session)
    session.fetch("subject_results").map { |subject| subject.fetch("expression_syntax") }
  end

  # The subjects `mutant environment subject list` prints, or nil when the
  # output isn't a complete list.
  def selection(output)
    lines = output.to_s.lines.map(&:strip)
    header = lines.index { |line| line.match?(/\ASubjects in environment: \d+\z/) } or return
    listed = lines[(header + 1)..].reject(&:empty?)
    listed if listed.size == lines[header][/\d+/].to_i
  end

  # The class or module a subject's method belongs to.
  def scope(subject) = subject[/\A[^#.]+/]

  # Does a mutant expression select this subject? "Foo*" is Foo and the
  # constants it nests; "Foo#bar" and "Foo.bar" are that method; "Foo" is Foo.
  def selects?(expression, subject)
    scope = scope(subject)
    if expression.end_with?("*")
      namespace = expression.delete_suffix("*")
      scope == namespace || scope.start_with?("#{namespace}::")
    elsif expression.match?(/[#.]/)
      subject == expression
    else
      scope == expression
    end
  end

  # Expressions that select nothing the change ran.
  def unmatched(session, expressions)
    ran = subjects(session)
    expressions.reject { |expression| ran.any? { |subject| selects?(expression, subject) } }
  end

  # Subjects whose results stop short of their mutations.
  def partial(session)
    session.fetch("subject_results")
      .reject { |subject| subject.fetch("amount_mutations") == subject.fetch("coverage_results").size }
      .map { |subject| subject.fetch("expression_syntax") }
  end

  def broken(session)
    results(session).select { |*, coverage| broken?(coverage) }.map { |subject, change, coverage| survivor(subject, change, coverage) }
  end

  # What is wrong with the base's own run: not the change's doing, but the
  # comparison can't be trusted without it.
  def base_gap(session)
    partial(session).map { |subject| "#{subject}: fewer results than mutations" } +
      broken(session).map(&:subject).uniq.map { |subject| "#{subject}: the tests fail on the code as written" }
  end

  # The step's message for a base that can't be compared with: the problem,
  # the first error line of what failed, and whose it is. A change to the
  # bundle or the harness can be what the base can't run under.
  def gap_lines(merge_base, problem, output:, changed:)
    error = output.to_s.lines.find { |line| line.match?(/Error|cannot load/) }
    blame = if changed.any? { |path| path.match?(BUNDLE) }
      "the base can't run under this change's bundle or harness; land the code change separately"
    else
      "this is the base's run failing, not a finding against the change"
    end
    [ "mutant-floor: GAP AT THE BASE (#{merge_base[0, 7]}): #{problem}", *("  #{error.strip}" if error), "mutant-floor: #{blame}" ]
  end

  # Where the app now defines the method a subject names, as the subjects that
  # would mutate it: its class's own (through its ancestors) when that is
  # still the app's, or else every class or module that defines a method of
  # that name and kind. Empty when no file under `paths` defines one: deleted,
  # renamed, or inherited from Rails or Object. Run inside the loaded app.
  def defined_as(subject, paths:)
    scope, separator, name = subject.partition(/[#.]/)
    singleton = separator == "."
    owned = [ own_method(scope, name, singleton) ].compact.select { |method| app_method?(method, paths) }
    found = owned.empty? ? methods_named(name, singleton).select { |method| app_method?(method, paths) } : owned
    found.map { |method| subject_of(method) }.uniq.sort
  end

  def own_method(scope, name, singleton)
    owner = Object.const_get(scope)
    (singleton ? owner.singleton_class : owner).instance_method(name)
  rescue NameError
    nil
  end

  # Every method of that name and kind that a named class or module defines itself.
  def methods_named(name, singleton)
    ObjectSpace.each_object(Module).filter_map do |mod|
      next unless Module.instance_method(:name).bind_call(mod) # some modules redefine name

      target = singleton ? mod.singleton_class : mod
      target.instance_method(name) if target.method_defined?(name, false) || target.private_method_defined?(name, false)
    end
  end

  def app_method?(method, paths)
    file = method.source_location&.first
    file && paths.any? { |path| file.start_with?("#{File.expand_path(path)}/") }
  end

  def subject_of(method)
    owner = method.owner
    owner.singleton_class? ? "#{owner.attached_object.name}.#{method.original_name}" : "#{owner.name}##{method.original_name}"
  end

  # The step's lookup, run inside the app loaded from `root`: a line for each
  # subject with where its APP_PATHS define it now.
  def lookup(subjects, root:)
    paths = APP_PATHS.map { |dir| File.join(root.to_s, dir) }
    subjects.map { |subject| "defined_as\t#{subject}\t#{defined_as(subject, paths:).join(",")}" }
  end

  # The lookup's lines read back from the runner's output, as subject => where.
  def looked_up(output)
    output.to_s.lines.filter_map { |line| line.chomp.split("\t", 3) if line.start_with?("defined_as\t") }
      .to_h { |_, subject, now| [ subject, now.to_s.split(",") ] }
  end

  # What the base's own config selected, from mutant's subject list there;
  # nil when the base has no config/mutant.yml, so selects nothing.
  def selected(listing)
    return [] if listing.nil?

    selection(listing) or raise ArgumentError, "not mutant's subject list: #{listing.inspect[0, 80]}"
  end

  # Base subjects the change doesn't run, which the step looks up in the change's app.
  def missing(tip, listing) = selected(listing) - subjects(tip)

  # The comparison as the step makes it: the base judged by its own config's
  # selection, the tip's config's expressions, what this change adds to
  # accepted.yml, and the `change:` entries the static checks accepted.
  def judge(tip:, base:, listing:, config:, accepted:, defined_as:, reasoned:)
    compare(tip, base, base_selected: selected(listing), expressions: config.dig("matcher", "subjects") || [], defined_as:, accepted:)
      .with(reasoned:)
  end

  # The change against its base. `base_selected` is what the base's own
  # config selects there; `defined_as` maps a base subject the change doesn't
  # run to where the change defines it (empty: nowhere); `accepted` holds the
  # entries this change adds to accepted.yml.
  def compare(tip, base, base_selected:, expressions:, defined_as:, accepted:)
    ran, base_ran = subjects(tip), subjects(base)
    vanished = base_selected - ran
    before = survivors(base, only: base_selected).transform_values(&:size)
    alive = survivors(tip)
    fresh = alive.flat_map { |key, list| list.drop(before.fetch(key, 0)) }
    carried, fresh = carry(fresh, before, vanished:, arrived: ran - base_ran - base_selected)
    equivalent, fresh, unused = accept(fresh, accepted.fetch("equivalents", []))
    departures = departures(vanished, ran, base_ran, defined_as)
    excused, left, deselected, removed = excuse(departures, accepted.fetch("config", []))

    Verdict.new(new_survivors: fresh, unused:, broken: broken(tip), partial: partial(tip), unmatched: unmatched(tip, expressions),
                left:, deselected:, removed:, carried:, equivalent:, moved: departures[:moved], renamed: departures[:renamed], excused:,
                timed_out: timed_out(tip, alive, before), reasoned: [])
  end

  # A survivor in a subject that only the change runs takes up one with the
  # same lines from a subject that only the base ran: a rename or a move.
  def carry(fresh, before, vanished:, arrived:)
    pool = before.select { |(subject, _), _| vanished.include?(subject) }.flat_map { |(subject, change), count| [ [ subject, change ] ] * count }
    carried = []
    remaining = fresh.reject do |survivor|
      next false unless arrived.include?(survivor.subject) && (index = pool.index { |_, change| change == survivor.change })

      carried << [ pool.delete_at(index).first, survivor.subject, survivor.change ]
    end
    [ carried, remaining ]
  end

  # Each equivalent entry accepts one new survivor; entries left over accept nothing.
  def accept(fresh, entries)
    open = entries.map { |entry| [ entry["subject"], normal(entry["change"]) ] }
    equivalent, remaining = fresh.partition do |survivor|
      (index = open.index([ survivor.subject, normal(survivor.change) ])) && open.delete_at(index)
    end
    [ equivalent, remaining, open ]
  end

  # Base subjects the change doesn't run: moved where a subject runs them;
  # renamed in place, beside a new subject of their own class; left out of
  # mutation; no longer selected by the change's config; or removed, by name,
  # from everywhere. Each is [subject, where it is now].
  def departures(missing, ran, base_ran, defined_as)
    sorted = { moved: [], renamed: [], left: [], deselected: [], removed: [] }
    renames = renames(missing.select { |subject| defined_as[subject]&.empty? }, ran - base_ran)
    missing.each do |subject|
      now = defined_as.fetch(subject, [ subject ])
      unrun = now - ran
      if now.empty? then sorted[renames[subject] ? :renamed : :removed] << [ subject, [ *renames[subject] ] ]
      elsif unrun.empty? then sorted[:moved] << [ subject, now ]
      elsif base_ran.include?(subject) then sorted[:left] << [ subject, unrun ]
      else sorted[:deselected] << [ subject, unrun ]
      end
    end
    sorted
  end

  # Pairs each subject the change no longer defines with a new subject of its
  # class, one for one: the same method name first, then in name order.
  # Returns subject => the new subject (nil: none left).
  def renames(vanished, arrived)
    pool = arrived.sort
    take = ->(subject, &match) { (index = pool.index { |new| scope(new) == scope(subject) && match.(new) }) && pool.delete_at(index) }
    same = vanished.to_h { |subject| [ subject, take.(subject) { |new| new.partition(/[#.]/).last == subject.partition(/[#.]/).last } ] }
    vanished.sort.to_h { |subject| [ subject, same[subject] || take.(subject) { true } ] }
  end

  # A config entry excuses the subjects it names, and nothing else. Returns
  # the excused, then what is left of each failing kind.
  def excuse(departures, entries)
    named = entries.flat_map { |entry| entry["subjects"] || [] }
    split = departures.values_at(:left, :deselected, :removed).map { |list| list.partition { |subject, _| named.include?(subject) } }
    [ split.flat_map(&:first), *split.map(&:last) ]
  end

  # Mutations alive at the base that the change kills only by a timeout.
  def timed_out(tip, alive, before)
    timeouts = results(tip).select { |*, coverage| evil?(coverage) && timed_out?(coverage) }.map { |subject, change, _| [ subject, change ] }
    before.flat_map do |key, count|
      [ key ] * [ count - alive.fetch(key, []).size, timeouts.count(key) ].min.clamp(0..)
    end
  end

  # Changes that weaken or strengthen both runs alike, by the `change:` entry
  # each needs, with the files: config/mutant.yml outside what it selects, and
  # the harness's code. `config` and `base_config` are config/mutant.yml as
  # parsed (nil: absent); `head` and `base` give a path's text (nil: absent).
  def weakenings(config, base_config, head, base)
    outside = ->(document) { document.merge("matcher" => document.fetch("matcher", {}).except("subjects", "ignore")) }
    {
      "config" => (base_config && outside.(config) != outside.(base_config) ? [ "config/mutant.yml" ] : []),
      "harness" => HARNESS_CODE.select { |path| base[path] && head[path] != base[path] }
    }.reject { |_, paths| paths.empty? }
  end

  CHANGES = { "config" => "changes outside its subjects and ignores", "harness" => "changes" }.freeze

  # Each weakening needs a `change:` entry this change adds. Returns
  # [problems, accepted], each accepted as [kind, paths, reason].
  def reasoned(weakenings, entries)
    problems, accepted = [], []
    weakenings.each do |kind, paths|
      reasons = entries.select { |entry| entry["change"] == kind }.map { |entry| entry["reason"].to_s.strip }
      problems << "#{paths.join(" and ")} #{CHANGES.fetch(kind)}; add a `change: #{kind}` entry to #{ACCEPTED} with the reason" if reasons.empty?
      accepted.concat(reasons.map { |reason| [ kind, paths, reason ] })
    end
    [ problems, accepted ]
  end

  # A file's YAML, or the problem with it, as [document, problem]; a file
  # that doesn't exist is [nil, nil].
  def parse_yaml(text, path)
    return [ nil, nil ] if text.nil?

    [ YAML.safe_load(text) || {}, nil ]
  rescue Psych::Exception => error
    [ nil, "#{path} is not valid YAML: #{error.message}" ]
  end

  LISTS = %w[equivalents config].freeze

  # What this change adds to accepted.yml, list by list, and what is wrong
  # with it. Each list at the base must be the start of the change's list.
  def accepted(head, base)
    problems = []
    return [ LISTS.to_h { |list| [ list, [] ] }, [ "#{ACCEPTED} must be a mapping of equivalents and config" ] ] unless head.nil? || head.is_a?(Hash)

    added = LISTS.to_h do |list|
      entries, before = list_in(head, list, problems), list_in(base, list, [])
      problems << "#{ACCEPTED} edits or removes an existing #{list} entry; append instead" unless entries.first(before.size) == before
      [ list, entries.drop(before.size) ]
    end
    [ added, problems + added.flat_map { |list, entries| entries.filter_map { |entry| entry_problem(list, entry) } } ]
  end

  def list_in(document, list, problems)
    entries = document.is_a?(Hash) ? document[list] : nil
    return entries || [] if entries.nil? || entries.is_a?(Array)

    problems << "#{ACCEPTED}: #{list} must be a list"
    []
  end

  def entry_problem(list, entry)
    wrong = entry_shape(list, entry)
    "an entry #{ACCEPTED} adds under #{list} #{wrong}: #{entry.inspect}" if wrong
  end

  def text?(value) = value.is_a?(String) && !value.strip.empty?

  def entry_shape(list, entry)
    if !entry.is_a?(Hash) then "is not a mapping"
    elsif !text?(entry["reason"]) then "gives no reason"
    elsif list == "equivalents" then equivalent_shape(entry)
    else config_shape(entry)
    end
  end

  def equivalent_shape(entry)
    "needs a subject and a change" unless text?(entry["subject"]) && text?(entry["change"])
  end

  # A config entry names what it excuses: subjects, or the change it gives the reason for.
  def config_shape(entry)
    subjects = entry["subjects"]
    if entry.key?("subjects") == entry.key?("change") then "needs either subjects or change, not both"
    elsif entry.key?("change") then ("names a change other than config or harness" unless %w[config harness].include?(entry["change"]))
    elsif !(subjects.is_a?(Array) && subjects.any? && subjects.all? { |subject| text?(subject) }) then "needs subjects as a list of names"
    end
  end

  # The step's lines for a verdict: what passes and is reported, then each failure.
  def report(verdict)
    [
      *section("Carried across a rename or move:", verdict.carried.map { |from, to, change| [ "survivor of #{from} carried to #{to}", change ] }),
      *section("Moved, or renamed in place:",
               verdict.moved.map { |from, now| "#{from} now runs as #{now.join(", ")}" } +
               verdict.renamed.map { |from, beside| "#{from} is no longer defined; renamed in place, beside #{beside.join(", ")}" }),
      *section("Killed only by a timeout, so tolerated (a slow runner can do this):", verdict.timed_out.map { |subject, change| [ subject, change ] }),
      *section("Accepted as equivalent by #{ACCEPTED}:", survivor_lines(verdict.equivalent)),
      *section("No longer mutated, excused by a config entry in #{ACCEPTED}:", whereabouts(verdict.excused)),
      *section("Accepted by a change: entry in #{ACCEPTED}:", verdict.reasoned.map { |kind, paths, reason| [ "change: #{kind}, for #{paths.join(", ")}", reason ] }),
      *section("FAIL: the tests fail, abort or time out on the code as written:", verdict.broken.map(&:subject).uniq),
      *section("FAIL: mutant stopped short of these subjects' mutations:", verdict.partial),
      *section("FAIL: named in config/mutant.yml, but no such subject ran:", verdict.unmatched),
      *section("FAIL: still defined, but no subject runs them any more (select where they live in config/mutant.yml):", whereabouts(verdict.left)),
      *section("FAIL: config/mutant.yml no longer selects these, and no config entry in #{ACCEPTED} names them:", whereabouts(verdict.deselected)),
      *section("FAIL: removed or renamed out of mutation's reach; add a `subjects:` entry to #{ACCEPTED} with the reason if it was deleted:",
               verdict.removed.map(&:first)),
      *section("FAIL: equivalents this change adds that match no new survivor:", verdict.unused.map { |subject, change| [ subject, change ] }),
      *section("FAIL: #{verdict.new_survivors.size} survivor(s) the base doesn't have:", survivor_lines(verdict.new_survivors))
    ]
  end

  # A heading and its items, each a line or [line, a change shown beneath it].
  def section(heading, items)
    return [] if items.empty?

    [ heading ] + items.flat_map do |line, change|
      [ "  #{line}", *change.to_s.lines.map { |text| "    #{text.chomp}" } ]
    end
  end

  def survivor_lines(survivors) = survivors.map { |s| [ "#{s.subject}  #{s.identification}", s.change ] }

  def whereabouts(subjects)
    subjects.map do |subject, now|
      if now.empty? then "#{subject}, removed"
      elsif now == [ subject ] then "#{subject}, still there but out of mutant's reach (define_method, or patched in from config/)"
      else "#{subject}, now in #{now.join(", ")}"
      end
    end
  end

  def copy_harness(from:, to:)
    HARNESS.each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(to, path)))
      FileUtils.cp(File.join(from, path), File.join(to, path))
    end
  end

  # The base runs on the change's bundle, so a gem bump changes both runs alike.
  def base_env(app_root)
    { "BUNDLE_GEMFILE" => File.join(app_root, "Gemfile"), "BUNDLE_LOCKFILE" => File.join(app_root, "Gemfile.lock"),
      "RAILS_ENV" => "test", "RUBYOPT" => nil }
  end

  # Re-anchoring: a baseline whose survivors or recorded subjects differ from
  # the one at the base must add an anchor that gives a reason. Returns the
  # problem, or nil.
  def anchor_problem(head, base)
    return if base && %w[survivors subjects].all? { |key| head[key] == base[key] }

    anchors = head.fetch("anchors", [])
    if anchors.size <= (base ? base.fetch("anchors", []).size : 0)
      "#{BASELINE} changes its survivors or subjects without adding an anchor"
    elsif anchors.last.fetch("reason", "").to_s.strip.empty?
      "#{BASELINE}'s newest anchor gives no reason"
    end
  end

  # The snapshot a full run records: every subject that ran, and the
  # survivors, keeping the earlier anchors.
  def record(session, baseline, at:, on:, reason:)
    survivors = survivors(session).group_by { |(subject, _), _| subject }.sort.to_h
      .transform_values { |pairs| pairs.flat_map { |(_, change), list| [ change ] * list.size }.sort }
    anchors = baseline.fetch("anchors", []) + [ { "at" => at, "on" => on, "reason" => reason } ]
    { "anchors" => anchors, "subjects" => subjects(session).sort, "survivors" => survivors }
  end
end
