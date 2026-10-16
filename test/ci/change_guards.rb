# Guards bin/change-guards runs against the base: changes that would switch a
# check off from inside the code it checks. See PRODUCT.md, CI-7.
module ChangeGuards
  # exhale 0.2.0's Exhale::SourceFiles::GENERATED, copied because the app's
  # bundle doesn't load exhale. A file whose first five lines hold a match is
  # skipped by both exhale floors. CI-7's test fails if exhale's changes.
  GENERATED = %r{
      \A\s*(?:<%\#|\#|//)\s*
      (?:this\ file\ is\ auto-?generated|this\ file\ is\ automatically\ generated|auto-?generated\ by
        |generated\ by\b.*\bdo\ not\ edit|do\ not\ edit|code\ generated\b.*\bdo\ not\ edit)
    }xi

  # RuboCop's directive comments that switch a cop off.
  DIRECTIVE = /#\s*rubocop\s*:\s*(?:disable|todo)\b/

  module_function

  def header?(text)
    text.to_s.each_line.first(5).any? { |line| line.match?(GENERATED) }
  end

  # pairs: [path, text at the base or nil, text now]. The paths under app/ or
  # lib/ that have a generator's header now and had none at the base.
  def new_headers(pairs)
    pairs.filter_map do |path, base, head|
      path if path.match?(%r{\A(app|lib)/}) && header?(head) && !header?(base)
    end
  end

  # base, head: { path => text }. [path, count at the base, count now] for
  # each file holding more directives than it did.
  def added_directives(base, head)
    head.filter_map do |path, text|
      before = base.fetch(path, "").scan(DIRECTIVE).size
      after = text.scan(DIRECTIVE).size
      [ path, before, after ] if after > before
    end.sort
  end
end
