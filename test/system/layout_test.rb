require "application_system_test_case"

# The two-column page: a metadata rail and a text column.
#
# Like the theme tests, these describe what a visitor can perceive rather than
# how it was built. They never name a preset, a token, a grid or a breakpoint,
# so the layout can be rebuilt underneath them and they still hold.
#
# The reading-measure test is the one that keeps the rail honest. The rail only
# exists because the measure is capped and cannot use the extra width; if the
# measure ever drifts outside the legible band, the rail has stopped being a
# reason for the container's width and started being a excuse for it.
class LayoutTest < ApplicationSystemTestCase
  WIDE = [ 1400, 900 ].freeze
  NARROW = [ 390, 844 ].freeze

  teardown { resize(*WIDE) }

  test "everything in the text column starts on the same edge" do
    visit root_path

    edges = [
      rect("h1")["left"],
      rect("main h2")["left"],
      rect("main .prose")["left"],
      rect("main .post-list a")["left"]
    ]

    assert_equal 1, edges.uniq.size,
      "blocks in the text column start at different edges: #{edges.inspect}"
  end

  test "metadata sits beside the writing rather than on top of it" do
    visit post_path(posts(:published_post))

    date = rect("main time")
    title = rect("h1")

    assert_operator date["right"], :<=, title["left"],
      "the date overlaps the title instead of sitting in the margin"
    assert_operator date["top"], :<, title["bottom"],
      "the date sits above the title rather than beside it"
  end

  test "dates line up in a column of their own" do
    visit posts_path

    lefts = rects("main time").map { |r| r["left"] }

    assert_operator lefts.size, :>=, 1, "expected at least one dated post"
    assert_equal 1, lefts.uniq.size, "dates do not share a left edge: #{lefts.inspect}"
  end

  test "the margin folds away on a narrow screen" do
    visit post_path(posts(:published_post))
    resize(*NARROW)

    date = rect("main time")
    title = rect("h1")

    assert_operator date["bottom"], :<=, title["top"] + 1,
      "the margin did not fold: the date is still beside the title on a phone"
    assert_not scrolls_horizontally?, "the page scrolls sideways on a phone"
  end

  # The two things an author can put on a page that are not plain prose: a
  # marked phrase and a note in the margin. Both are content, so both have to
  # survive every design rather than being drawn in one and dropped in three.
  test "a marked phrase is drawn in every design" do
    visit root_path

    design_options.each do |option|
      option.click
      name = option[:"aria-label"]

      assert_selector "main mark", text: "home"
      assert drawn_mark?,
        "#{name} renders a marked phrase with nothing drawn behind it, so the " \
        "emphasis the author wrote is invisible here"
    end
  end

  test "a margin note sits beside its section and folds above it on a phone" do
    visit root_path

    note = rect("main .section .note")
    heading = rect("main .section h2")

    assert_operator note["right"], :<=, heading["left"],
      "the note is in the text column rather than in the margin"

    resize(*NARROW)
    assert_operator rect("main .section .note")["bottom"], :<=,
      rect("main .section h2")["top"] + 1,
      "the note did not fold above its heading on a phone"
    assert_not scrolls_horizontally?, "the page scrolls sideways on a phone"
  end

  test "the reading measure stays inside the legible band in every design" do
    visit root_path

    design_options.each do |option|
      option.click
      name = option[:"aria-label"]
      characters = settled_measure

      assert_operator characters, :>=, 65,
        "#{name} sets prose at #{characters.round(1)} characters per line, below the 65 floor"
      assert_operator characters, :<=, 75,
        "#{name} sets prose at #{characters.round(1)} characters per line, above the 75 ceiling"
    end
  end

  private
    def design_options
      all("[role='radio']")
    end

    def resize(width, height)
      page.driver.browser.manage.window.resize_to(width, height)
    end

    def rect(selector)
      rects(selector).first || raise("no element matched #{selector.inspect}")
    end

    def rects(selector)
      evaluate_script(<<~JS)
        Array.from(document.querySelectorAll(#{selector.to_json})).map((el) => {
          const box = el.getBoundingClientRect();
          return {
            left: Math.round(box.left), right: Math.round(box.right),
            top: Math.round(box.top), bottom: Math.round(box.bottom),
            width: Math.round(box.width)
          };
        })
      JS
    end

    # A mark whose instrument resolved to nothing computes to background-image:
    # none, because an invalid custom-property substitution drops the whole
    # declaration back to its initial value rather than erroring.
    def drawn_mark?
      evaluate_script(<<~JS)
        (() => {
          const mark = document.querySelector("main mark");
          return !!mark && getComputedStyle(mark).backgroundImage !== "none";
        })()
      JS
    end

    def scrolls_horizontally?
      evaluate_script("document.documentElement.scrollWidth > window.innerWidth")
    end

    # Characters per line of body prose, measured against the font actually in
    # use rather than assumed from the stylesheet. Webfonts swap in after first
    # paint and change the answer, so this waits for the reading to hold still.
    def measure_in_ch
      evaluate_script(<<~JS).to_f
        (() => {
          const prose = document.querySelector("main .prose");
          if (!prose) return 0;
          const probe = document.createElement("span");
          probe.style.cssText = "visibility:hidden;position:absolute;white-space:pre";
          probe.textContent = "0".repeat(100);
          prose.appendChild(probe);
          const ch = probe.getBoundingClientRect().width / 100;
          probe.remove();
          return ch ? prose.getBoundingClientRect().width / ch : 0;
        })()
      JS
    end

    def settled_measure(timeout: 5, stable_for: 0.4)
      deadline = Time.now + timeout
      interval = 0.1
      required = (stable_for / interval).ceil
      previous = measure_in_ch
      streak = 0

      loop do
        sleep interval
        current = measure_in_ch

        if (current - previous).abs < 0.05
          streak += 1
          return current if streak >= required
        else
          previous = current
          streak = 0
        end

        raise "the reading measure never stopped changing" if Time.now > deadline
      end
    end
end
