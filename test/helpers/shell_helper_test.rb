require "test_helper"

class ShellHelperTest < ActionView::TestCase
  test "the pages open can go to are the ones the helper has paths for" do
    assert_equal Shell::OPENABLE, shell_pages.keys
  end

  test "the browser gets every string it prints, with the presets to list" do
    strings = shell_strings

    assert_equal SiteSetting::PRESETS.join(", "), strings[:presets]
    %i[theme_switched theme_unknown theme_usage mode_switched].each do |key|
      assert strings[key].present?, "missing #{key}"
    end
  end
end
