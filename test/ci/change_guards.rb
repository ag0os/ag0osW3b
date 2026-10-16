# Guards bin/change-guards runs against the base: changes that would switch a
# check off from inside the code it checks. See PRODUCT.md, CI-7.
module ChangeGuards
  # RuboCop's directive comments that switch a cop off.
  RUBOCOP_DISABLE = /#\s*rubocop\s*:\s*(?:disable|todo)\b/
  # mutant 0.17's Mutant::Subject::Config::DISABLE_REGEXP, copied because
  # bin/change-guards runs outside the app's bundle; CI-7 fails if mutant's
  # changes. mutant applies it to a comment's text after its leading #.
  MUTANT_DISABLE = /(\s|^)mutant:disable(?:\s|$)/

  module_function

  # Files exhale would compare by their language (*_candidates) but doesn't
  # read (not in *_listed), that it read at the base or that didn't exist.
  def newly_unlisted(head_candidates, head_listed, base_candidates, base_listed)
    unread_at_base = base_candidates - base_listed
    (head_candidates - head_listed - unread_at_base).sort
  end

  def directive_counts(text)
    # Every # starts a comment's text for mutant, so a space stands in for it.
    { rubocop: text.scan(RUBOCOP_DISABLE).size, mutant: text.tr("#", " ").scan(MUTANT_DISABLE).size }
  end

  # base, head: { path => text }. [path, kind, count at the base, count now]
  # for each file holding more directives of a kind than it did.
  def added_directives(base, head)
    head.flat_map do |path, text|
      before = directive_counts(base.fetch(path, ""))
      directive_counts(text).filter_map { |kind, after| [ path, kind, before[kind], after ] if after > before[kind] }
    end.sort
  end
end
