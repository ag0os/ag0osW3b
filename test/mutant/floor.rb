# The mutation floor (bin/mutant-floor): a run passes when every mutation it
# leaves alive is already in the committed baseline, test/mutant/baseline.yml.
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

  Verdict = Data.define(:new_survivors, :broken, :stale) do
    def pass? = new_survivors.empty? && broken.empty?
  end

  module_function

  # The lines a mutation diff removes and adds, which is all that identifies it.
  def change(diff)
    diff.lines.grep(/\A[-+]/).map(&:rstrip).join("\n")
  end

  # Mutations a session result left uncovered: an evil mutation no test killed
  # is a survivor; any other kind (a neutral one) means the tests fail on the
  # code as written, which no baseline can accept.
  def uncovered(session)
    session.fetch("subject_results").flat_map do |subject|
      subject.fetch("coverage_results").filter_map do |coverage|
        next if coverage.fetch("criteria_result").values.any?

        mutation = coverage.fetch("mutation_result")
        [ mutation.fetch("mutation_type"),
          Survivor.new(subject: subject.fetch("expression_syntax"),
                       change: change(mutation.fetch("mutation_diff")),
                       identification: mutation.fetch("mutation_identification")) ]
      end
    end
  end

  # Subjects a session ran, so that stale entries are only reported for them.
  def subjects(session)
    session.fetch("subject_results").map { |subject| subject.fetch("expression_syntax") }
  end

  # Matches each survivor against the baseline, one entry each: two identical
  # survivors in one subject need two entries.
  def compare(session, baseline)
    remaining = baseline.fetch("survivors", {}).transform_values(&:dup)
    new_survivors = []
    broken = []
    uncovered(session).each do |type, survivor|
      next broken << survivor unless type == "evil"

      entries = remaining.fetch(survivor.subject, [])
      index = entries.index(survivor.change)
      index ? entries.delete_at(index) : new_survivors << survivor
    end
    stale = subjects(session).flat_map { |subject| remaining.fetch(subject, []).map { |change| [ subject, change ] } }
    Verdict.new(new_survivors:, broken:, stale:)
  end

  # Re-anchoring: a baseline whose survivors differ from the one at the base
  # must add an anchor that gives a reason. Returns the problem, or nil.
  def anchor_problem(head, base)
    return if base && head.fetch("survivors", {}) == base.fetch("survivors", {})

    anchors = head.fetch("anchors", [])
    if anchors.size <= (base ? base.fetch("anchors", []).size : 0)
      "#{BASELINE} changes its survivors without adding an anchor"
    elsif anchors.last.fetch("reason", "").to_s.strip.empty?
      "#{BASELINE}'s newest anchor gives no reason"
    end
  end

  # The baseline a full run records, keeping the earlier anchors.
  def record(session, baseline, at:, on:, reason:)
    survivors = uncovered(session).select { |type, _| type == "evil" }.map(&:last)
      .group_by(&:subject).sort.to_h.transform_values { |list| list.map(&:change).sort }
    anchors = baseline.fetch("anchors", []) + [ { "at" => at, "on" => on, "reason" => reason } ]
    { "anchors" => anchors, "survivors" => survivors }
  end
end
