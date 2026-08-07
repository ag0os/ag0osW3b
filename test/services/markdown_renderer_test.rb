require "test_helper"

class MarkdownRendererTest < ActiveSupport::TestCase
  test "renders markdown" do
    assert_includes MarkdownRenderer.render("**bold**"), "<strong>bold</strong>"
  end

  test "==phrase== becomes a mark" do
    assert_includes MarkdownRenderer.render("I turn intent into ==working systems==."),
      "<mark>working systems</mark>"
  end

  # The mark is applied to the rendered tree, not the source, so a run of
  # equals signs inside code stays exactly what the author typed.
  test "a mark inside code is left alone" do
    inline = MarkdownRenderer.render("Compare with `a ==b== c`.")
    assert_includes inline, "a ==b== c"
    assert_not_includes inline, "<mark>"

    fenced = MarkdownRenderer.render("```ruby\nx ==y== z\n```")
    assert_not_includes fenced, "<mark>"
  end

  test "equals signs that are not a mark stay put" do
    assert_not_includes MarkdownRenderer.render("x == y"), "<mark>"
    assert_not_includes MarkdownRenderer.render("a ==  == b"), "<mark>"
  end

  test "marking a plain string escapes everything else" do
    marked = MarkdownRenderer.mark("<script>alert(1)</script> and ==this==")

    assert_includes marked, "<mark>this</mark>"
    assert_includes marked, "&lt;script&gt;"
    assert_not_includes marked, "<script>"
    assert_predicate marked, :html_safe?
  end

  test "unmark leaves the words and drops the marks" do
    assert_equal "Senior engineer building AI-native workflows.",
      MarkdownRenderer.unmark("Senior engineer building ==AI-native workflows==.")
  end
end
