require "test_helper"

class ShellTest < ActiveSupport::TestCase
  test "help, in any case, and a blank line" do
    [ "help", "HELP", "?", "", "   " ].each do |line|
      assert_equal :help, Shell.run(line).view, "#{line.inspect} should print help"
    end
  end

  test "whoami" do
    assert_equal :whoami, Shell.run("whoami").view
  end

  test "cat prints a page's visible sections in order" do
    result = Shell.run("cat home")

    assert_equal :sections, result.view
    assert_equal %w[home_intro home_proof], result.locals[:sections].map(&:key),
      "expected the visible home sections, without the hidden one"
  end

  test "a page name is shorthand for cat" do
    assert_equal :sections, Shell.run("home").view
    assert_equal [], Shell.run("about").locals[:sections], "a page with nothing on it still prints as a page"
  end

  test "cat finds a section by key, and by the end of its key" do
    assert_equal [ sections(:home_intro) ], Shell.run("cat home_intro").locals[:sections]
    assert_equal [ sections(:home_proof) ], Shell.run("cat proof").locals[:sections]
    assert_equal [ sections(:home_proof) ], Shell.run("cat proof.md").locals[:sections], "a .md suffix is tolerated"
  end

  test "cat never prints a hidden section" do
    assert_equal :message, Shell.run("cat home_hidden").view
    assert_equal :message, Shell.run("cat hidden").view
  end

  test "cat without a target, or with an unknown one, says so" do
    assert_equal I18n.t("shell.cat.usage"), Shell.run("cat").locals[:text]
    assert_equal I18n.t("shell.cat.not_found", name: "nope"), Shell.run("cat nope").locals[:text]
  end

  test "writing lists published posts only" do
    result = Shell.run("writing")

    assert_equal :writing, result.view
    assert_includes result.locals[:posts], posts(:published_post)
    assert_not_includes result.locals[:posts], posts(:draft_post)
  end

  test "ls counts what there is to read" do
    result = Shell.run("ls")

    assert_equal :ls, result.view
    assert_equal 2, result.locals[:pages]["home"]
    assert_equal 1, result.locals[:posts]
  end

  test "open names a page the helper knows the path to" do
    assert_equal({ page: "work" }, Shell.run("open work").locals)
    assert_equal({ page: "writing" }, Shell.run("open posts").locals)
    assert_equal({ page: "about" }, Shell.run("cd /about/").locals)
    assert_equal I18n.t("shell.open.usage"), Shell.run("open").locals[:text]
    assert_equal I18n.t("shell.open.not_found", name: "nowhere"), Shell.run("open nowhere").locals[:text]
  end

  test "lang switches to an available locale and reports the current one" do
    assert_equal({ locale: :es }, Shell.run("lang es").locals)
    assert_equal({ locale: :en }, Shell.run("lang EN").locals)
    assert_equal :message, Shell.run("lang fr").view
    assert_match(/English/, Shell.run("lang").locals[:text])
  end

  test "browser-only commands are recognised so the server can say they need JavaScript" do
    Shell::CLIENT_SIDE.each do |name|
      result = Shell.run("#{name} anything")
      assert_equal :needs_js, result.view, "#{name} should be a browser command"
      assert_equal name, result.locals[:name]
    end
  end

  test "anything else is not a command" do
    result = Shell.run("what do you do for clients?")

    assert_equal :unknown, result.view
    assert_equal "what do you do for clients?", result.locals[:line]
  end

  test "input is made printable and capped" do
    result = Shell.run("cat\thome\n\n  extra   words")
    assert_equal "cat home extra words", result.line

    long = Shell.run("x" * 1000)
    assert_equal Shell::MAX_LENGTH, long.line.length
  end

  test "the opening comes from the setting, blanks ignored" do
    SiteSetting["shell_opening"] = "whoami; ; help ;"

    assert_equal %i[whoami help], Shell.opening.map(&:view)
  ensure
    SiteSetting.find_by(key: "shell_opening")&.destroy
  end

  test "every command completion candidate is something run understands" do
    Shell::COMMANDS.each do |name|
      assert_not_equal :unknown, Shell.run(name).view, "#{name} is offered for completion but not understood"
    end
  end
end
