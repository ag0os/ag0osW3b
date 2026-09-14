require "application_system_test_case"

# The shell as a visitor uses it. Like the theme tests, these describe what
# can be perceived: what gets printed, where the page goes, whether the design
# changed. They know nothing about Turbo, streams or the controller.
class ShellTest < ApplicationSystemTestCase
  test "the greeting types itself out and leaves the prompt waiting" do
    visit root_path

    assert_selector "#shell kbd", text: "whoami"
    assert_selector "#shell", text: "Commands:", wait: 8
    assert_selector "#shell input[name=line]"
  end

  test "a command is answered in place without leaving the page" do
    visit root_path

    prompt.send_keys("ls", :enter)

    assert_selector "#shell kbd", text: "ls"
    assert_selector "#shell", text: "pages:"
    assert_current_path root_path
    assert_equal "", prompt.value, "the field was not cleared after the command ran"
  end

  test "a page prints its content, marks included" do
    visit root_path

    prompt.send_keys("cat home", :enter)

    assert_selector "#shell mark", text: "home"
  end

  test "open goes to the page" do
    visit root_path

    prompt.send_keys("open work", :enter)

    assert_selector "h1", text: "Work"
    assert_current_path work_path
  end

  test "theme from the prompt changes the design and the switcher agrees" do
    visit root_path
    before = settled_appearance

    prompt.send_keys("theme spec", :enter)

    assert_selector "#shell", text: "theme: spec"
    assert_not_equal before, settled_appearance, "the design did not change"
    assert_equal "Spec theme", find("[role='radio'][aria-checked='true']")[:"aria-label"]
  end

  test "dark and light from the prompt flip the mode" do
    visit root_path
    was_light = light?

    prompt.send_keys(was_light ? "dark" : "light", :enter)

    assert_not_equal was_light, light?, "the mode did not flip"
  end

  test "the arrow keys recall earlier commands" do
    visit root_path

    prompt.send_keys("ls", :enter)
    assert_selector "#shell", text: "pages:"
    prompt.send_keys("whoami", :enter)
    assert_selector "#shell kbd", text: "whoami", count: 2

    prompt.send_keys(:arrow_up)
    assert_equal "whoami", prompt.value
    prompt.send_keys(:arrow_up)
    assert_equal "ls", prompt.value
    prompt.send_keys(:arrow_down, :arrow_down)
    assert_equal "", prompt.value
  end

  test "tab completes a command" do
    visit root_path

    prompt.send_keys("who", :tab)

    assert_equal "whoami ", prompt.value
  end

  test "clear empties the screen" do
    visit root_path
    assert_selector "#shell kbd", text: "whoami"

    prompt.send_keys("clear", :enter)

    assert_no_selector "#shell kbd", text: "whoami"
  end

  test "lang es restarts the shell in Spanish" do
    visit root_path

    prompt.send_keys("lang es", :enter)

    assert_selector "#shell", text: "idioma: Español"
    assert_selector "#shell input[placeholder='escribí help, o hacé una pregunta']"
    assert_selector "nav a", text: "Sobre mí"
  end

  private
    def prompt
      find("#shell input[name=line]")
    end

    def appearance
      evaluate_script(<<~JS)
        (() => {
          const style = getComputedStyle(document.body);
          return { background: style.backgroundColor, text: style.color, font: style.fontFamily };
        })()
      JS
    end

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

    def light?
      look = settled_appearance
      lightness(look["background"]) > lightness(look["text"])
    end

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
