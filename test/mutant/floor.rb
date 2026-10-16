# The mutation floor (bin/mutant-floor): a run passes when every mutation it
# leaves alive is in the committed baseline, test/mutant/baseline.yml, and
# every entry in the baseline is still a mutation that survives.
#
# A survivor is known by its subject and the lines its mutation removes and
# adds. Line numbers, file paths and the unchanged rest of the method are left
# out, so editing one method, or code above it, leaves every other survivor
# where it was.
require "json"
require "yaml"

module MutantFloor
  BASELINE = "test/mutant/baseline.yml"

  Survivor = Data.define(:subject, :change, :identification)

  # Everything but timed_out fails the run.
  Verdict = Data.define(:new_survivors, :broken, :partial, :unmatched, :killed, :vanished, :timed_out) do
    def pass? = [ new_survivors, broken, partial, unmatched, killed, vanished ].all?(&:empty?)
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

  def uncovered?(coverage) = coverage.fetch("criteria_result").values.none?

  def survivor(subject, change, coverage)
    Survivor.new(subject:, change:, identification: coverage.dig("mutation_result", "mutation_identification"))
  end

  # Subjects a session ran.
  def subjects(session)
    session.fetch("subject_results").map { |subject| subject.fetch("expression_syntax") }
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

  # Expressions that select nothing, then subjects the baseline names (with
  # entries, or recorded as having run) that didn't run.
  def unmatched(session, baseline, expressions)
    ran = subjects(session)
    expressions.reject { |expression| ran.any? { |subject| selects?(expression, subject) } } +
      ((baseline.fetch("survivors", {}).keys + baseline.fetch("subjects", [])).uniq - ran)
  end

  # Subjects whose results stop short of their mutations.
  def partial(session)
    session.fetch("subject_results")
      .reject { |subject| subject.fetch("amount_mutations") == subject.fetch("coverage_results").size }
      .map { |subject| subject.fetch("expression_syntax") }
  end

  # Matches each survivor against the baseline, one entry each: two identical
  # survivors in one subject need two entries. An entry left over is a
  # mutation that a test now kills, that only timed out, or that mutant no
  # longer makes.
  def compare(session, baseline, expressions:)
    remaining = baseline.fetch("survivors", {}).transform_values(&:dup)
    new_survivors = []
    broken = []
    killed_results = Hash.new { |hash, key| hash[key] = [] }
    results(session).each do |subject, change, coverage|
      unless uncovered?(coverage)
        killed_results[[ subject, change ]] << coverage.fetch("criteria_result")
        next
      end
      next broken << survivor(subject, change, coverage) unless coverage.dig("mutation_result", "mutation_type") == "evil"

      entries = remaining.fetch(subject, [])
      index = entries.index(change)
      index ? entries.delete_at(index) : new_survivors << survivor(subject, change, coverage)
    end

    stale = { killed: [], vanished: [], timed_out: [] }
    remaining.each do |subject, entries|
      entries.each do |change|
        criteria = killed_results[[ subject, change ]]
        if (index = criteria.index { |result| result["test_result"] || result["process_abort"] })
          kind = :killed
        elsif (index = criteria.index { |result| result["timeout"] })
          kind = :timed_out
        else
          kind = :vanished
        end
        criteria.delete_at(index) if index
        stale[kind] << [ subject, change ]
      end
    end

    Verdict.new(new_survivors:, broken:, partial: partial(session), unmatched: unmatched(session, baseline, expressions), **stale)
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

  # The baseline a full run records: every subject that ran, and the
  # survivors, keeping the earlier anchors.
  def record(session, baseline, at:, on:, reason:)
    survivors = results(session)
      .select { |_, _, coverage| uncovered?(coverage) && coverage.dig("mutation_result", "mutation_type") == "evil" }
      .group_by(&:first).sort.to_h.transform_values { |list| list.map { |_, change, _| change }.sort }
    anchors = baseline.fetch("anchors", []) + [ { "at" => at, "on" => on, "reason" => reason } ]
    { "anchors" => anchors, "subjects" => subjects(session).sort, "survivors" => survivors }
  end
end
