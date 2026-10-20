require "test_helper"

class LocaleNegotiationContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#preferred_locale" if respond_to?(:cover)

  test "LC-1 on a bare address a site-language cookie decides over the browser" do
    cookies[:locale] = "es"
    get about_path(locale: nil), headers: { "Accept-Language" => "en" }
    assert_language "es"

    cookies[:locale] = "en"
    get about_path(locale: nil), headers: { "Accept-Language" => "es" }
    assert_language "en"
  end

  test "LC-3 a bare address without a cookie or browser language falls back to English" do
    get about_path(locale: nil)

    assert_language "en"
  end

  test "LC-3 a bare address with only unsupported browser languages falls back to English" do
    get about_path(locale: nil), headers: { "Accept-Language" => "fr-FR, de;q=0.9" }

    assert_language "en"
  end

  test "LC-3 an unknown cookie is skipped on a bare address and the browser decides" do
    cookies[:locale] = "fr"
    get about_path(locale: nil), headers: { "Accept-Language" => "es" }
    assert_language "es"

    get about_path(locale: nil)
    assert_language "en"
  end

  test "LC-1 a language path overrides a conflicting saved choice" do
    cookies[:locale] = "es"
    get "/en/about", headers: { "Accept-Language" => "es" }
    assert_response :success
    assert_select "html[lang=en]"
  end

  test "LC-3 a language path precedes unknown cookie and malformed browser fallback" do
    cookies[:locale] = "unknown"
    get "/es/about", headers: { "Accept-Language" => ",,;q=," }
    assert_response :success
    assert_select "html[lang=es]"
  end

  test "LC-2 a bare address accepts a supported browser language in uppercase" do
    get "/about", headers: { "Accept-Language" => "ES-ar" }
    assert_response :success
    assert_language "es"
  end

  private
    def assert_language(code, message = nil)
      assert_select "html[lang=?]", code, message: [ message, "page in #{code}" ].compact.join(": ")
    end
end
