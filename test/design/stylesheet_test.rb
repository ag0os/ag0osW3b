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

  # Tokens that make a preset a design rather than a palette. All have defaults
  # in :root, so omitting one fails silently as "looks like the others" instead
  # of erroring, which is exactly the kind of thing worth a test.
  IDENTITY_TOKENS = %w[
    font-display font-body font-mono
    density rule-width rule-style heading-marker
    ease dur dur-enter
  ].freeze

  # One delight per preset, and exactly one. Each is a token slot that is inert
  # in :root and answered by a single preset, the way --cursor-content is: the
  # mechanism ships in all four, the performance belongs to one.
  #
  # Both halves matter. A slot two presets answer stops being either one's
  # signature, and a preset collecting several is how delight turns into the
  # noise it is supposed to be the opposite of.
  DELIGHTS = {
    "workshop" => "ink-stroke",
    "console"  => "lamp-display",
    "spec"     => "dimension-display",
    "terminal" => "endmark-display"
  }.freeze

  test "stylesheets exist" do
    assert_equal %w[admin.css application.css components.css fonts.css themes.css],
      STYLESHEETS.map { |path| path.basename.to_s }.sort
  end

  test "every preset declares its own identity tokens" do
    preset_blocks.each do |name, body|
      missing = IDENTITY_TOKENS.reject { |token| body.match?(/^\s*--#{token}:/) }

      assert_empty missing,
        "preset #{name} does not set: #{missing.join(', ')}. It will silently " \
        "inherit the defaults and read as a recolour of another preset."
    end
  end

  test "no two presets share the same design fingerprint" do
    fingerprints = preset_blocks.to_h do |name, body|
      [ name, %w[density rule-style heading-marker font-display].map { |t| body[/^\s*--#{t}:\s*([^;]+);/m, 1].to_s.strip } ]
    end

    duplicates = fingerprints.group_by { |_, print| print }.select { |_, group| group.size > 1 }

    assert_empty duplicates.values.flatten(1).map(&:first),
      "these presets are indistinguishable on density, rule style, heading " \
      "marker and display font, so switching between them barely shows"
  end

  test "each delight belongs to exactly one preset" do
    DELIGHTS.each do |owner, token|
      answering = preset_blocks.select { |_, body| body.match?(/^\s*--#{token}:/) }.keys

      assert_equal [ owner ], answering,
        "--#{token} is #{owner}'s delight. Answered by #{answering.join(', ').presence || 'nobody'}, " \
        "it is either site furniture or a preset that has stopped being quiet."
    end
  end

  test "every preset answers a delight, and only its own" do
    owed = preset_blocks.keys.to_h { |name| [ name, DELIGHTS.fetch(name, "") ] }

    owed.each do |name, own|
      strays = DELIGHTS.values.reject { |token| token == own }
        .select { |token| preset_blocks.fetch(name).match?(/^\s*--#{token}:/) }

      assert_not_equal "", own,
        "preset #{name} has no delight of its own. Give it one that names the " \
        "object it is built on, and add it to DELIGHTS."
      assert_empty strays,
        "preset #{name} also answers #{strays.join(', ')}, which belongs to another preset"
    end
  end

  test "every delight slot is inert by default" do
    css = strip_comments(Rails.root.join("app/assets/stylesheets/themes.css"))

    DELIGHTS.each_value do |token|
      assert_equal 2, css.scan(/^\s*--#{token}:/).length,
        "--#{token} should be declared exactly twice: an inert default in :root " \
        "and the one preset that answers it. Without the default the other " \
        "three presets resolve it to nothing at all, which is not the same thing."
    end
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

  # A misspelled font filename does not error anywhere: the @font-face simply
  # never loads and every preset quietly falls back to a system stack. The site
  # looks fine, slightly wrong, forever.
  test "every declared webfont file exists" do
    fonts_css = strip_comments(Rails.root.join("app/assets/stylesheets/fonts.css"))
    referenced = fonts_css.scan(/url\("([^"]+\.woff2)"\)/).flatten

    assert_operator referenced.size, :>=, 8, "expected a webface per preset role"

    missing = referenced.reject { |file| Rails.root.join("app/assets/fonts", file).exist? }
    assert_empty missing,
      "declared in fonts.css but absent from app/assets/fonts: #{missing.join(', ')}. " \
      "Run bin/fetch-fonts."
  end

  test "every declared webfont family is actually used by a preset" do
    fonts_css = strip_comments(Rails.root.join("app/assets/stylesheets/fonts.css"))
    families = fonts_css.scan(/font-family:\s*"([^"]+)"/).flatten.uniq
    themes = strip_comments(Rails.root.join("app/assets/stylesheets/themes.css"))

    unused = families.reject { |family| themes.include?("\"#{family}\"") }
    assert_empty unused,
      "these faces are downloaded and served but no preset asks for them: #{unused.join(', ')}"
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

    def preset_blocks
      @preset_blocks ||= strip_comments(Rails.root.join("app/assets/stylesheets/themes.css"))
        .scan(/\[data-theme="([a-z]+)"\]\s*\{(.*?)^\s*\}/m)
        .to_h
    end
end
