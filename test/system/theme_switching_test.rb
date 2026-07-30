require "application_system_test_case"

# Behaviour of the theme system as a visitor experiences it.
#
# These tests deliberately know nothing about how theming is implemented. They
# never mention data attributes, localStorage, preset names, CSS classes, or
# token values, so the implementation can be rewritten underneath them and they
# still describe the promise the site makes. What they assert on is what a
# visitor can perceive: what the page looks like, what the controls are called,
# and what state those controls report to assistive technology.
#
# Because the design options are discovered from the page rather than listed
# here, adding a fifth design gets covered automatically.
class ThemeSwitchingTest < ApplicationSystemTestCase
  # The bug this exists for: a stray "*/" in a stylesheet comment voided the
  # entire design system. Every route still returned 200, every other test still
  # passed, and the site rendered as unstyled HTML. Nothing catches that except
  # looking at a rendered page.
  test "the site renders with a design applied, not as bare HTML" do
    visit root_path

    assert_selector "h1"
    assert_not_equal "rgba(0, 0, 0, 0)", appearance["background"],
      "the page has no background colour, which means the stylesheets loaded but produced no rules"
    assert_operator distance(appearance["background"], appearance["text"]), :>, 0.3,
      "text and background are nearly the same shade, so the page is unreadable"
  end

  test "each design option renders a visibly different design" do
    visit root_path

    designs = design_options.map do |option|
      option.click
      settled_appearance
    end

    assert_operator designs.size, :>=, 2, "expected more than one design to choose from"
    assert_equal designs.size, designs.uniq.size,
      "two design options render identically, so switching between them does nothing visible"
  end

  test "content stays legible in every design" do
    visit root_path

    design_options.each_with_index do |option, index|
      option.click
      look = settled_appearance

      assert_selector "h1", visible: true
      assert_operator distance(look["background"], look["text"]), :>, 0.3,
        "design ##{index + 1} renders text too close in shade to its background"
    end
  end

  test "choosing a design changes how the page looks" do
    visit root_path
    before = settled_appearance

    other_than_selected.click

    assert_not_equal before, settled_appearance,
      "picking a different design left the page looking the same"
  end

  test "a chosen design is still in effect when following a link" do
    visit root_path
    other_than_selected.click
    chosen = settled_appearance

    click_link "Writing"
    assert_selector "h1", text: "Writing"

    assert_equal chosen, settled_appearance,
      "the chosen design was forgotten when navigating to another page"
  end

  # Deliberately a fresh page load rather than a link click. Following a link is
  # a Turbo visit, which swaps the body but keeps the document, so the design
  # would survive even if nothing had been remembered. Only a full load proves
  # the choice actually persists.
  test "a chosen design is remembered on a later visit" do
    visit root_path
    other_than_selected.click
    chosen = settled_appearance

    visit posts_path
    assert_selector "h1", text: "Writing"

    assert_equal chosen, settled_appearance,
      "the chosen design was not remembered across a fresh page load"
  end

  test "a chosen light or dark setting is remembered on a later visit" do
    visit root_path
    mode_toggle.click
    chosen = light?

    visit posts_path
    assert_selector "h1", text: "Writing"

    assert_equal chosen, light?,
      "the light/dark choice was not remembered across a fresh page load"
  end

  test "light and dark can be switched independently of the chosen design" do
    visit root_path
    was_light = light?

    mode_toggle.click
    assert_not_equal was_light, light?, "toggling did not switch between a light and a dark rendering"

    # The two axes are independent: changing the design must not silently
    # throw away the light/dark choice.
    now_light = light?
    other_than_selected.click
    settled_appearance

    assert_equal now_light, light?,
      "choosing a different design reset the light/dark preference"
  end

  test "the switcher reports which design is selected" do
    visit root_path

    assert_equal 1, selected_designs.size, "expected exactly one design to be marked as selected"

    target = other_than_selected
    name = target[:"aria-label"]
    target.click

    assert_equal 1, selected_designs.size
    assert_equal name, selected_designs.first[:"aria-label"],
      "the design that was clicked is not the one reported as selected"
  end

  test "the light and dark control reports its state" do
    visit root_path
    before = mode_toggle["aria-pressed"]

    mode_toggle.click

    assert_not_equal before, mode_toggle["aria-pressed"],
      "the toggle did not report a changed state after being pressed"
  end

  test "designs can be changed with the keyboard alone" do
    visit root_path
    before = settled_appearance

    selected_designs.first.send_keys(:arrow_right)

    assert_not_equal before, settled_appearance,
      "arrow keys did not move between designs"
    assert_equal 1, selected_designs.size
  end

  private
    # Design options are whatever the page offers as a choice, discovered by
    # role rather than by class or preset name.
    def design_options
      all("[role='radio']")
    end

    def selected_designs
      all("[role='radio'][aria-checked='true']")
    end

    def other_than_selected
      selected = selected_designs.first
      design_options.find { |option| option != selected } ||
        raise("expected at least two design options")
    end

    def mode_toggle
      find("button[aria-pressed]")
    end

    def appearance
      evaluate_script(<<~JS)
        (() => {
          const style = getComputedStyle(document.body);
          return { background: style.backgroundColor, text: style.color, font: style.fontFamily };
        })()
      JS
    end

    # Colour transitions mean a reading taken just after a click can land
    # mid-crossfade, and two equal readings are not enough: at the very start of
    # a transition the colour has not visibly moved yet, so it reads as stable
    # while still being the old value. Require it to hold steady for longer than
    # any transition on the page before trusting it.
    def settled_appearance(timeout: 5, stable_for: 0.5)
      deadline = Time.now + timeout
      interval = 0.1
      required = (stable_for / interval).ceil
      previous = appearance
      streak = 0

      loop do
        sleep interval
        current = appearance

        if current == previous
          streak += 1
          return current if streak >= required
        else
          previous = current
          streak = 0
        end

        raise "the page never stopped changing appearance" if Time.now > deadline
      end
    end

    # Light mode means the background is lighter than the text. That is the
    # visitor-facing definition, and it does not care how the colour was authored.
    def light?
      look = settled_appearance
      lightness(look["background"]) > lightness(look["text"])
    end

    def distance(one, other)
      (lightness(one) - lightness(other)).abs
    end

    # Handles whichever format the browser reports computed colours in. OKLCH
    # already carries perceptual lightness; rgb() gets a luminance approximation.
    def lightness(color)
      numbers = color.to_s.scan(/-?\d+(?:\.\d+)?%?/)
      return 0.0 if numbers.empty?

      if color.to_s.start_with?("oklch", "oklab", "lab", "lch")
        value = numbers.first
        value.end_with?("%") ? value.to_f / 100 : value.to_f
      else
        red, green, blue = numbers.first(3).map(&:to_f)
        (0.2126 * red + 0.7152 * green + 0.0722 * blue) / 255
      end
    end
end
