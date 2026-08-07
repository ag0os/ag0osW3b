require "test_helper"

# The site icon.
#
# It is the one design asset that is not CSS, which means none of the other
# guards in test/design see it. It also fails silently in the worst way: an SVG
# the browser cannot parse renders as a blank tab, and every route still
# returns 200.
class IconTest < ActiveSupport::TestCase
  SVG = Rails.root.join("public/icon.svg")
  EXPORTS = { "public/icon.png" => 512, "public/apple-touch-icon.png" => 180 }.freeze

  test "the icon is valid XML" do
    document = Nokogiri::XML(File.read(SVG)) { |config| config.strict }

    assert_empty document.errors, "public/icon.svg does not parse: #{document.errors.join(', ')}"
    assert_equal "svg", document.root.name
  end

  # The bug this is really for: a double hyphen is legal in CSS and in prose and
  # illegal inside an XML comment, so writing a token name in a note about the
  # drawing voids the whole file.
  test "the icon has no double hyphen inside a comment" do
    comments = Nokogiri::XML(File.read(SVG)).xpath("//comment()").map(&:content)

    assert_not_empty comments, "expected the icon to explain itself"
    comments.each do |comment|
      assert_not_includes comment, "--",
        "a double hyphen inside an XML comment ends the document early"
    end
  end

  test "the icon is self-contained and themed" do
    svg = File.read(SVG)

    # Not a search for "http": the SVG namespace is a URL and always will be.
    # What matters is whether anything is fetched at render time, which a
    # favicon cannot do reliably in any browser.
    assert_empty svg.scan(/(?:href|src)\s*=|url\(|@import/),
      "the icon fetches something instead of carrying its own drawing"
    assert_includes svg, "prefers-color-scheme",
      "the icon does not answer a dark tab, so it will sit as a light square in one"
    assert_not_includes svg, 'fill="red"',
      "this is still the framework's default icon"
  end

  # iOS ignores SVG icons and a manifest wants raster, so these exports have to
  # exist. bin/render-icons regenerates them from the SVG.
  test "the raster exports exist" do
    EXPORTS.each do |path, size|
      file = Rails.root.join(path)

      assert file.exist?, "#{path} is missing. Run bin/render-icons."
      assert_operator file.size, :>, 500, "#{path} looks empty"
      assert_equal size, png_width(file), "#{path} is not #{size}px wide. Run bin/render-icons."
    end
  end

  private
    # PNG header: 8-byte signature, then an IHDR chunk whose width is a 4-byte
    # big-endian integer at offset 16.
    def png_width(path)
      File.binread(path, 4, 16).unpack1("N")
    end
end
