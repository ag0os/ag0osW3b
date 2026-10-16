# The test count bin/test-count checks a test run against. See PRODUCT.md,
# CI-9.
module TestCount
  REMOVALS = "test/ci/test_removals.yml"
  SUMMARY = /^(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips$/

  module_function

  # The last Minitest summary line in a run's output, or nil.
  def summary(output)
    runs, _assertions, failures, errors = output.scan(SUMMARY).last&.map(&:to_i)
    { runs:, failures:, errors: } if runs
  end

  # Why a run doesn't pass, if it doesn't. base_count is how many tests the
  # base has in this suite; each removal this change adds (in head_removals,
  # not base_removals) lowers it for its suite and must give a reason.
  def problems(output:, success:, base_count:, suite:, head_removals:, base_removals:)
    found = summary(output)
    problems = []
    problems << "the run exited nonzero" unless success
    return problems << "the output holds no Minitest summary line, so nothing shows the tests ran" unless found

    problems << "#{found[:failures]} failures, #{found[:errors]} errors" if found[:failures] + found[:errors] > 0
    added = head_removals - base_removals
    added.select { |removal| removal["reason"].to_s.strip.empty? }.each do |removal|
      problems << "a removal in #{REMOVALS} gives no reason: #{removal.inspect}"
    end
    removed = added.select { |removal| removal["suite"] == suite }.sum { |removal| removal["tests"].to_i }
    if found[:runs] < base_count - removed
      problems << "#{found[:runs]} runs, but the base has #{base_count} tests" + (removed.zero? ? "" : " (#{removed} removed on purpose)")
    end
    problems
  end
end
