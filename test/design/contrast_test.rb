require "test_helper"

# Makes the accessibility contract in PRODUCT.md a failing build rather than a
# good intention.
#
# Four presets times two modes is eight surfaces, which is more than anyone
# reliably eyeballs. This parses the OKLCH values straight out of themes.css,
# converts them to sRGB, and asserts WCAG 2.2 AA on every pair that carries
# meaning. Add a preset and it is covered automatically: the test discovers
# presets from the stylesheet, it does not keep its own list.
class ContrastTest < ActiveSupport::TestCase
  THEMES_CSS = Rails.root.join("app/assets/stylesheets/themes.css")

  AA_TEXT = 4.5   # body text
  AA_LARGE = 3.0  # large text, icons, and meaningful UI boundaries

  # fg role, bg role, minimum ratio, why it matters
  TEXT_PAIRS = [
    [ "text",        "bg",        AA_TEXT,  "body text on the page" ],
    [ "text",        "surface",   AA_TEXT,  "body text on a raised surface" ],
    [ "text",        "bg-subtle", AA_TEXT,  "body text on a recessed surface" ],
    [ "text-muted",  "bg",        AA_TEXT,  "secondary text on the page" ],
    [ "text-muted",  "bg-subtle", AA_TEXT,  "secondary text on a recessed surface" ],
    [ "text-faint",  "bg",        AA_LARGE, "placeholder and tertiary text" ],
    [ "accent",      "bg",        AA_TEXT,  "links" ],
    [ "accent-hover", "bg",       AA_TEXT,  "links on hover" ],
    [ "danger",      "bg",        AA_TEXT,  "destructive action text" ]
  ].freeze

  UI_PAIRS = [
    [ "accent-contrast", "accent-fill", AA_TEXT,  "label on a filled button" ],
    [ "border-strong",   "bg",          AA_LARGE, "input and button boundaries" ],
    [ "border-strong",   "surface",     AA_LARGE, "boundaries against a raised surface" ],
    [ "accent",          "bg",          AA_LARGE, "the focus ring, which is var(--accent)" ],
    [ "success",         "bg",          AA_LARGE, "status indicator" ]
  ].freeze

  test "every preset declares every role in both modes" do
    presets.each do |name, roles|
      %w[l d].each do |mode|
        expected = (TEXT_PAIRS + UI_PAIRS).flat_map { |fg, bg, _, _| [ fg, bg ] }.uniq
        missing = expected.reject { |role| roles.key?("#{mode}-#{role}") }
        assert_empty missing,
          "preset #{name} is missing #{mode == 'l' ? 'light' : 'dark'} tokens: #{missing.join(', ')}"
      end
    end
  end

  test "text and UI pairs meet WCAG AA in every preset and mode" do
    each_surface do |name, mode, roles|
      (TEXT_PAIRS + UI_PAIRS).each do |fg, bg, minimum, purpose|
        ratio = contrast(roles.fetch("#{mode}-#{fg}"), roles.fetch("#{mode}-#{bg}"))

        assert_operator ratio, :>=, minimum,
          "#{name}/#{mode_name(mode)}: --#{fg} on --#{bg} is #{ratio.round(2)}:1, " \
          "needs #{minimum}:1 (#{purpose})"
      end
    end
  end

  test "syntax highlighting is legible on code blocks in every preset and mode" do
    light_l, dark_l = highlight_lightness

    each_surface do |name, mode, roles|
      lightness = mode == "l" ? light_l : dark_l
      background = roles.fetch("#{mode}-bg-subtle")

      highlight_tokens(name).each do |token, (chroma, hue)|
        ratio = contrast([ lightness, chroma, hue ], background)

        assert_operator ratio, :>=, AA_TEXT,
          "#{name}/#{mode_name(mode)}: --hl-#{token} on --bg-subtle is " \
          "#{ratio.round(2)}:1, needs #{AA_TEXT}:1"
      end
    end
  end

  test "the highlight lightness pair is still wired to both modes" do
    assert_equal 3, css.scan(/--hl-l:\s*[\d.]+/).length,
      "expected --hl-l once for light and twice for dark (media query plus attribute)"
  end

  private
    def css
      @css ||= File.read(THEMES_CSS)
    end

    # { "workshop" => { "l-bg" => [l, c, h], "d-bg" => [...] }, ... }
    def presets
      @presets ||= css.scan(/\[data-theme="([a-z]+)"\]\s*\{(.*?)^\s*\}/m).to_h do |name, body|
        roles = body.scan(/--([ld])-([a-z-]+):\s*oklch\(\s*([\d.]+)\s+([\d.]+)\s+([\d.]+)\s*\)/)
                    .to_h { |mode, role, l, c, h| [ "#{mode}-#{role}", [ l.to_f, c.to_f, h.to_f ] ] }
        [ name, roles ]
      end.tap do |found|
        assert_equal SiteSetting::PRESETS.sort, found.keys.sort,
          "themes.css and SiteSetting::PRESETS disagree about which presets exist"
      end
    end

    def each_surface
      presets.each do |name, roles|
        %w[l d].each { |mode| yield name, mode, roles }
      end
    end

    def mode_name(mode)
      mode == "l" ? "light" : "dark"
    end

    def highlight_tokens(preset)
      body = css[/\[data-theme="#{preset}"\]\s*\{(.*?)^\s*\}/m, 1]
      body.scan(/--hl-([a-z]+):\s*oklch\(var\(--hl-l\)\s+([\d.]+)\s+([\d.]+)\)/)
          .to_h { |token, c, h| [ token, [ c.to_f, h.to_f ] ] }
    end

    def highlight_lightness
      values = css.scan(/--hl-l:\s*([\d.]+)/).flatten.map(&:to_f)
      [ values.first, values.last ]
    end

    # ---- Color math -------------------------------------------------------
    # OKLCH to linear sRGB (Björn Ottosson's Oklab matrices), then WCAG
    # relative luminance. Out-of-gamut channels are clamped, which is what a
    # browser's gamut mapping approximates.
    def linear_srgb(lightness, chroma, hue)
      radians = hue * Math::PI / 180
      a = chroma * Math.cos(radians)
      b = chroma * Math.sin(radians)

      l = (lightness + 0.3963377774 * a + 0.2158037573 * b)**3
      m = (lightness - 0.1055613458 * a - 0.0638541728 * b)**3
      s = (lightness - 0.0894841775 * a - 1.2914855480 * b)**3

      [
        4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
        -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
        -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
      ].map { |channel| channel.clamp(0.0, 1.0) }
    end

    def luminance(color)
      red, green, blue = linear_srgb(*color)
      0.2126 * red + 0.7152 * green + 0.0722 * blue
    end

    def contrast(foreground, background)
      values = [ luminance(foreground), luminance(background) ]
      (values.max + 0.05) / (values.min + 0.05)
    end
end
