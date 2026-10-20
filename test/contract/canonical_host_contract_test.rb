require "test_helper"

# PD-5 from docs/contracts/production.md, as tests: the
# www host redirects to the apex, and the apex is untouched. It asserts only on
# HTTP: the status and the Location header.
class CanonicalHostContractTest < ActionDispatch::IntegrationTest
  APEX = "https://agoos.dev"

  test "PD-5 the www root answers 301 to the apex root" do
    host! "www.agoos.dev"
    get "/"

    assert_response :moved_permanently
    assert_equal "#{APEX}/", response.location
  end

  test "PD-5 a deep path keeps its path and query string" do
    host! "www.agoos.dev"

    [ "/writing/a-post?ref=mastodon&utm_source=x", "/feed.atom", "/admin/posts/a-post/edit", "/no-such-page?q=1" ].each do |path|
      get path

      assert_response :moved_permanently, path
      assert_equal "#{APEX}#{path}", response.location, path
    end
  end

  test "PD-5 it holds over https and for every method" do
    https!
    host! "www.agoos.dev"

    { post: "/session", patch: "/locale?x=1", put: "/admin/posts/a-post", delete: "/session", head: "/about" }.each do |verb, path|
      send verb, path

      assert_response :moved_permanently, "#{verb} #{path}"
      assert_equal "#{APEX}#{path}", response.location, "#{verb} #{path}"
    end
  end

  test "PD-5 the apex serves normally" do
    host! "agoos.dev"

    get "/"
    assert_response :ok

    get "/about?ref=x"
    assert_response :ok

    patch "/locale", params: { locale: "es" }
    assert_response :see_other
    assert_redirected_to "http://agoos.dev/es"
  end
end
