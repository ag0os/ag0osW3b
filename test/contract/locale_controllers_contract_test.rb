require "test_helper"

class LocaleRedirectContractTest < ActionController::TestCase
  tests LocalesController
  cover "LocalesController*" if respond_to?(:cover)
  cover "LocalizedLinksHelper#public_page_path" if respond_to?(:cover)

  test "LC-6 LC-7 valid choices save a permanent protected cookie and rebuild the public route" do
    %w[es en].each do |locale|
      @request.env["HTTP_REFERER"] = "http://test.host/es/about?host=evil.example&ref=a%2Fb#note"
      patch :update, params: { locale: locale }
      assert_response :see_other
      assert_redirected_to "http://test.host/#{locale}/about?host=evil.example&ref=a%2Fb"
      cookie = @response.cookies.fetch("locale")
      assert_equal locale, cookie
      header = @response.headers.fetch("Set-Cookie").to_s
      assert_match(/expires=/i, header)
      assert_match(/samesite=lax/i, header)
      assert_match(/httponly/i, header)
    end
  end

  test "LC-8 origin and route rejection falls back to the chosen home" do
    [ nil, "http://evil.example/about", "//test.host/about", "ftp://test.host:80/about",
      "http://user@test.host/about", "http://test.host:81/about", "garbage ://",
      "/admin", "/missing", "/locale", "/session/new", "/passwords/new", "/up" ].each do |referer|
      @request.env["HTTP_REFERER"] = referer
      patch :update, params: { locale: "es" }
      assert_response :see_other
      assert_redirected_to "http://test.host/es"
    end
  end

  test "LC-7 LC-8 public relative routes and either HTTP scheme retain the raw query" do
    { "/about?ref=x" => "/es/about?ref=x", "https://test.host:80/en/contact" => "/es/contact",
      "http://test.host/en/feed.xml?ref=x" => "/es/feed.xml?ref=x", "/writing/nope" => "/es/writing/nope",
      "/" => "/es" }.each do |referer, target|
      @request.env["HTTP_REFERER"] = referer
      patch :update, params: { locale: "es" }
      assert_redirected_to "http://test.host#{target}"
    end
  end

  test "LC-9 invalid choices rebuild the recognised route at its own locale without writing a cookie" do
    [ "fr", "ES", "", nil, [ "es" ] ].each do |choice|
      { "http://test.host//about?ref=a%2Fb" => "/about?ref=a%2Fb",
        "http://test.host//es/about?locale=en" => "/es/about?locale=en", "/admin" => "/", nil => "/" }.each do |referer, target|
        @request.env["HTTP_REFERER"] = referer
        patch :update, params: { locale: choice }.compact
        assert_response :see_other
        assert_redirected_to "http://test.host#{target}"
        refute @response.cookies.key?("locale")
      end
    end
  end
end
