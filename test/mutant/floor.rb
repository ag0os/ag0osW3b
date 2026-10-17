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

  Survivor = Data.define(:subject, :change, :identification)

  # The first seven fail the run; the rest are reported.
  Verdict = Data.define(:new_survivors, :unused, :broken, :partial, :unmatched, :left, :deselected,
                        :carried, :equivalent, :moved, :excused, :timed_out) do
    def pass? = [ new_survivors, unused, broken, partial, unmatched, left, deselected ].all?(&:empty?)
  end

  module_function

  # The lines a mutation diff removes and adds, which is all that identifies it.
  def change(diff)
    diff.to_s.lines.grep(/\A[-+]/).map(&:rstrip).join("\n")
  end

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

  # Does a mutant expression select this subject? "Foo*" is Foo and the
  # constants it nests; "Foo#bar" and "Foo.bar" are that method; "Foo" is Foo.
  def selects?(expression, subject)
    scope = subject[/\A[^#.]+/]
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

  # Where the app now defines the method a subject names, as the subject that
  # would mutate it, or nil when no file under `paths` defines it: deleted,
  # renamed, or inherited from Rails or Object. Run inside the loaded app.
  def defined_as(subject, paths:)
    scope, separator, name = subject.partition(/[#.]/)
    owner = Object.const_get(scope)
    method = (separator == "." ? owner.singleton_class : owner).instance_method(name)
    file = method.source_location&.first
    return unless file && paths.any? { |path| file.start_with?("#{File.expand_path(path)}/") }

    method.owner.singleton_class? ? "#{method.owner.attached_object.name}.#{name}" : "#{method.owner.name}##{name}"
  rescue NameError
    nil
  end

  # The change against its base. `base_selected` is what the base's own
  # config selects there; `defined_as` maps a base subject the change doesn't
  # run to where the change defines it (nil: nowhere); `accepted` holds the
  # entries this change adds to accepted.yml.
  def compare(tip, base, base_selected:, expressions:, defined_as:, accepted:)
    ran, base_ran = subjects(tip), subjects(base)
    before = survivors(base, only: base_selected).transform_values(&:size)
    fresh = survivors(tip).flat_map { |key, list| list.drop(before.fetch(key, 0)) }
    carried, fresh = carry(fresh, before, vanished: base_selected - ran, arrived: ran - base_ran - base_selected)
    equivalent, fresh, unused = accept(fresh, accepted.fetch("equivalents", []))
    departures = departures(base_selected - ran, ran, base_ran, defined_as)
    excused, deselected = accepted.fetch("config", []).empty? ? [ [], departures[:deselected] ] : [ departures[:deselected], [] ]

    Verdict.new(new_survivors: fresh, unused:, broken: broken(tip), partial: partial(tip), unmatched: unmatched(tip, expressions),
                left: departures[:left], deselected:, carried:, equivalent:, moved: departures[:moved], excused:,
                timed_out: timed_out(tip, base, before))
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
    open = entries.map { |entry| [ entry["subject"], entry["change"] ] }
    equivalent, remaining = fresh.partition do |survivor|
      (index = open.index([ survivor.subject, survivor.change ])) && open.delete_at(index)
    end
    [ equivalent, remaining, open ]
  end

  # Base subjects the change doesn't run: gone or moved where a subject runs
  # them, left out of mutation, or no longer selected by the change's config.
  def departures(missing, ran, base_ran, defined_as)
    sorted = { moved: [], left: [], deselected: [] }
    missing.each do |subject|
      now = defined_as.fetch(subject, subject)
      if now.nil? || ran.include?(now) then sorted[:moved] << [ subject, now ]
      elsif base_ran.include?(subject) then sorted[:left] << subject
      else sorted[:deselected] << subject
      end
    end
    sorted
  end

  # Mutations alive at the base that the change kills only by a timeout.
  def timed_out(tip, base, before)
    timeouts = results(tip).select { |*, coverage| evil?(coverage) && timed_out?(coverage) }.map { |subject, change, _| [ subject, change ] }
    now = survivors(tip).transform_values(&:size)
    before.flat_map do |key, count|
      [ key ] * [ count - now.fetch(key, 0), timeouts.count(key) ].min.clamp(0..)
    end
  end

  # A change to config/mutant.yml beyond what it selects, which would weaken
  # both runs alike, needs a config entry this change adds. Returns the problem, or nil.
  def config_problem(head, base, reasons)
    return if base.nil? || reasons.any?

    strip = ->(config) { config.merge("matcher" => config.fetch("matcher", {}).except("subjects", "ignore")) }
    "config/mutant.yml changes outside its subjects and ignores; add a config entry to #{ACCEPTED} with the reason" if strip.(head) != strip.(base)
  end

  # Entries in head's list that base's doesn't hold, counting copies.
  def added(head, base)
    left = base.dup
    head.reject { |entry| (index = left.index(entry)) && left.delete_at(index) }
  end

  def reasonless(entries) = entries.select { |entry| entry.fetch("reason", "").to_s.strip.empty? }

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
