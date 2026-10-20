require "test_helper"

# The post page's Contract, as tests of its public HTTP response. PP-1 in
# PRODUCT.md guards the shared layout's handling of the post's excerpt.
class PostPageContractTest < ActionDispatch::IntegrationTest
  test "PP-1 descriptions use the unmarked excerpt escaped exactly once" do
    post = posts(:published_post)
    post.update!(excerpt: 'a < b ==c== & "quotes" &lt;tag&gt;')

    get post_path(slug: post)
    assert_response :success

    description = 'a < b c & "quotes" &lt;tag&gt;'
    [ 'meta[name="description"]', 'meta[property="og:description"]' ].each do |selector|
      assert_select selector, count: 1
      assert_equal description, css_select(selector).first["content"]
    end
    escaped = "a &lt; b c &amp; &quot;quotes&quot; &amp;lt;tag&amp;gt;"
    assert_includes response.body, %(<meta name="description" content="#{escaped}">)
    assert_includes response.body, %(<meta property="og:description" content="#{escaped}">)
  end
end
