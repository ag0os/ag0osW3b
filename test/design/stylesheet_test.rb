require "test_helper"

# Structural guards on the stylesheets.
#
# These exist because a single stray "*/" inside a comment in themes.css once
# silently voided the entire token layer. Every route still returned 200, every
# other test still passed, and the site rendered as unstyled HTML. Nothing in a
# Rails test suite notices that, so these rules do.
class StylesheetTest < ActiveSupport::TestCase
  STYLESHEETS = Rails.root.glob("app/assets/stylesheets/*.css").freeze

  # Components consume the semantic contract. Presets define it. A stylesheet
  # that is not themes.css has no business knowing preset names.
  CONTRACT_CONSUMERS = %w[application.css components.css admin.css].freeze

  test "stylesheets exist" do
    assert_equal %w[admin.css application.css components.css themes.css],
      STYLESHEETS.map { |path| path.basename.to_s }.sort
  end

  test "comments are balanced" do
    STYLESHEETS.each do |path|
      assert_not_includes strip_comments(path), "*/",
        "#{path.basename} has an unbalanced comment: a '*/' survives comment " \
        "stripping, which means a comment closed early and the CSS after it is " \
        "being parsed as garbage. Check for '*/' inside comment prose."
    end
  end

  test "braces are balanced" do
    STYLESHEETS.each do |path|
      css = strip_comments(path)

      assert_equal css.count("{"), css.count("}"),
        "#{path.basename} has unbalanced braces"
    end
  end

  test "no hardcoded colors outside the token layer" do
    STYLESHEETS.each do |path|
      css = strip_comments(path)

      assert_empty css.scan(/#[0-9a-fA-F]{3,8}\b/),
        "#{path.basename} hardcodes a hex color. Color belongs in themes.css " \
        "as a preset token, or it will only be right in one of eight surfaces."

      assert_empty css.scan(/\b(?:rgba?|hsla?)\(/),
        "#{path.basename} hardcodes an rgb/hsl color. Author color in OKLCH " \
        "in themes.css instead."
    end
  end

  test "components never reference a preset by name" do
    CONTRACT_CONSUMERS.each do |name|
      css = strip_comments(Rails.root.join("app/assets/stylesheets", name))

      assert_empty css.scan(/\[data-theme[~^|*$]?=/),
        "#{name} branches on a preset. If a component needs to differ per " \
        "preset, the difference belongs in the token contract, not here."
    end
  end

  test "every referenced custom property is defined somewhere" do
    defined = STYLESHEETS.flat_map { |path| strip_comments(path).scan(/(--[a-z0-9-]+)\s*:/) }.flatten.to_set
    referenced = STYLESHEETS.flat_map { |path| strip_comments(path).scan(/var\(\s*(--[a-z0-9-]+)/) }.flatten.to_set

    assert_empty (referenced - defined).sort,
      "these custom properties are used but never defined (likely a typo)"
  end

  test "every preset in SiteSetting has a token block" do
    css = strip_comments(Rails.root.join("app/assets/stylesheets/themes.css"))
    declared = css.scan(/\[data-theme="([a-z]+)"\]/).flatten.uniq

    assert_equal SiteSetting::PRESETS.sort, declared.sort,
      "SiteSetting::PRESETS and themes.css disagree. A preset offered in the " \
      "switcher with no token block renders with every role undefined."
    assert_equal SiteSetting::PRESETS.sort, SiteSetting::PRESET_LABELS.keys.sort,
      "every preset needs a human-readable label for the switcher"
  end

  private
    # Mirrors how a CSS parser handles comments: /* ... */, no nesting.
    def strip_comments(path)
      File.read(path).gsub(%r{/\*.*?\*/}m, "")
    end
end
