# What the weekly mutation run on main (bin/mutant-weekly) reports: the
# survivors that neither the newest anchor in test/mutant/baseline.yml records
# nor an equivalents entry in test/mutant/accepted.yml accepts, and the calls
# to `gh` that put them in one issue. See docs/contracts/ci.md, CI-10 to CI-12.
require_relative "../mutant/floor"

module MutantWeekly
  LABEL = "mutation-weekly"
  TITLE = "Mutation survivors on main"

  # What one run found: the survivors left over, the anchor's survivors that
  # are no longer alive, and the issue's body.
  Report = Data.define(:delta, :killed, :body)

  module_function

  # How many survivors each [subject, change] has, from [subject, change] pairs.
  def tally(pairs)
    pairs.each_with_object(Hash.new(0)) { |(subject, change), counts| counts[[ subject, MutantFloor.normal(change) ]] += 1 }
  end

  def recorded(baseline) = tally((baseline["survivors"] || {}).flat_map { |subject, changes| changes.map { |change| [ subject, change ] } })

  def equivalents(accepted) = tally((accepted["equivalents"] || []).map { |entry| [ entry["subject"], entry["change"] ] })

  # The run's survivors by key, the key as the gate makes it (CI-4).
  def alive(session)
    MutantFloor.survivors(session).values.flatten.group_by { |survivor| [ survivor.subject, MutantFloor.normal(survivor.change) ] }
  end

  # The survivors the anchor and the equivalents don't account for: each
  # anchor line and each entry takes up one survivor of its key.
  def delta(session, baseline:, accepted:)
    allowed = recorded(baseline).merge(equivalents(accepted)) { |_, anchored, accepted_count| anchored + accepted_count }
    alive(session).flat_map { |key, survivors| survivors.drop(allowed[key]) }
  end

  # The anchor's survivors the run no longer has, as [subject, change], once per copy.
  def killed(session, baseline:)
    now = alive(session)
    recorded(baseline).flat_map { |key, count| [ key ] * (count - now.fetch(key, []).size).clamp(0..) }
  end

  # Why the session can't be reported on: a subject cut short, a neutral that
  # fails, an expression in config/mutant.yml that matched nothing, or
  # subjects other than those mutant lists for that config (`listing`, the
  # output of `mutant environment subject list`).
  def trouble(session, expressions:, listing:)
    MutantFloor.base_gap(session) + MutantFloor.unmatched(session, expressions).map { |expression| "#{expression}: matched no subject" } +
      inventory(session, listing)
  end

  def inventory(session, listing)
    expected = MutantFloor.selection(listing) or return [ "mutant could not list the subjects config/mutant.yml selects" ]
    ran = MutantFloor.subjects(session)
    (expected - ran).map { |subject| "#{subject}: selected, but the session has no result for it" } +
      (ran - expected).map { |subject| "#{subject}: in the session, but not selected" }
  end

  # mutant exits 0 when every mutation is killed and 1 when some survive.
  NORMAL_EXITS = [ 0, 1 ].freeze

  # Why a mutant run didn't complete, from its exit and what it printed: a
  # session file alone proves nothing, since mutant writes it as it goes.
  def incomplete(status, output, session)
    return [ "mutant was killed by signal #{status.termsig}" ] if status.signaled?
    return [ "mutant exited #{status.exitstatus.inspect}" ] unless NORMAL_EXITS.include?(status.exitstatus)

    mutations, results = %w[Mutations Results].map { |label| output.to_s.scan(/^#{label}:\s+(\d+)$/).last&.first&.to_i }
    return [ "mutant printed no final report, so the run didn't finish" ] unless results

    recorded = MutantFloor.results(session).size
    [ *("mutant reported #{results} results of #{mutations} mutations" unless results == mutations),
      *("the session holds #{recorded} results, but mutant reported #{results}" unless recorded == results) ]
  end

  def timeouts(session) = MutantFloor.results(session).count { |*, coverage| MutantFloor.evil?(coverage) && MutantFloor.timed_out?(coverage) }

  def report(session, baseline:, accepted:, at:, wall:)
    delta = delta(session, baseline:, accepted:)
    killed = killed(session, baseline:)
    Report.new(delta:, killed:, body: body(session, delta:, killed:, anchor: baseline.fetch("anchors", []).last&.fetch("at", nil), at:, wall:))
  end

  def body(session, delta:, killed:, anchor:, at:, wall:)
    [
      "Survivors on main at `#{at}` that the newest anchor in `#{MutantFloor::BASELINE}` (at `#{anchor}`) doesn't record " \
      "and `#{MutantFloor::ACCEPTED}` doesn't accept as equivalent: **#{delta.size}**.",
      timing(session, wall:),
      *delta.group_by(&:subject).sort.map { |subject, survivors| subject_section(subject, survivors) },
      *killed_section(killed),
      "Triage each survivor: kill it with a Contract sentence and its test, or accept it in `#{MutantFloor::ACCEPTED}` with a reason. " \
      "Re-anchor with `bin/mutant-floor --record \"REASON\"`. This issue only reports (docs/contracts/ci.md, CI-12)."
    ].join("\n\n") + "\n"
  end

  def timing(session, wall:)
    mutations = session.fetch("subject_results").sum { |subject| subject.fetch("amount_mutations") }
    took = wall ? format("; the step took %.0f s", wall) : ""
    format("%d subjects, %d mutations, %d alive, %d killed only by a timeout. mutant ran %.0f s%s.",
           MutantFloor.subjects(session).size, mutations, alive(session).values.sum(&:size), timeouts(session), session.fetch("runtime", 0), took)
  end

  def subject_section(subject, survivors)
    "### #{subject}\n\n" + survivors.map { |survivor| "`#{survivor.identification}`\n```diff\n#{survivor.change}\n```" }.join("\n\n")
  end

  def killed_section(killed)
    return [] if killed.empty?

    [ "### Killed since the anchor\n\nThe anchor records these, and this run didn't find them alive:\n\n" +
      killed.map { |subject, change| "#{subject}\n```diff\n#{change}\n```" }.join("\n\n") ]
  end

  # The `gh` calls for one run, given the open issues with the label (their
  # numbers) and whether the label exists. At most one issue is ever open: a
  # delta updates the oldest open one, and opens one only when none is.
  def issue_commands(open:, labelled:, delta_size:, body_file:, at:)
    issue = open.min&.to_s
    if delta_size.zero?
      issue ? [ [ "issue", "comment", issue, "--body", "Main is clean at #{at}: no survivor outside the anchor and accepted.yml." ], [ "issue", "close", issue ] ] : []
    elsif issue
      [ [ "issue", "edit", issue, "--body-file", body_file ], [ "issue", "comment", issue, "--body", "Run at #{at}: #{delta_size} survivor(s) outside the anchor and accepted.yml." ] ]
    else
      [ *([ [ "label", "create", LABEL, "--description", "The weekly mutation run on main" ] ] unless labelled),
        [ "issue", "create", "--title", TITLE, "--label", LABEL, "--body-file", body_file ] ]
    end
  end
end
