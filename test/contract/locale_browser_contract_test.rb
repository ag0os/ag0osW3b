require "test_helper"

class LocaleBrowserContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#accept_language" if respond_to?(:cover)

  test "LC-2 on a bare address without a cookie the first supported browser language decides" do
    [ "fr-FR, es-AR;q=0.9, en;q=0.8", "fr-FR,es;q=0.9" ].each do |header|
      get about_path(locale: nil), headers: { "Accept-Language" => header }

      assert_language "es", header
    end
  end

  test "LC-2 bare-address negotiation ignores the region and case of a browser entry" do
    get about_path(locale: nil), headers: { "Accept-Language" => "ES-ar" }

    assert_language "es"
  end

  test "LC-2 bare-address negotiation requires a whole supported language subtag" do
    get about_path(locale: nil), headers: { "Accept-Language" => "esu, en" }

    assert_language "en"
  end

  test "LC-2 bare-address browser entries retain their sent order rather than q sorting" do
    get about_path(locale: nil), headers: { "Accept-Language" => "en;q=0.1, es;q=0.9" }

    assert_language "en"
  end

  test "LC-2 a language path overrides browser preference without a cookie" do
    get "/es/about", headers: { "Accept-Language" => "en" }
    assert_response :success
    assert_select "html[lang=es]"
  end

  test "LC-2 bare-address negotiation trims whitespace before a quality parameter" do
    get "/about", headers: { "Accept-Language" => "fr, ES ;q=0.1, en" }
    assert_response :success
    assert_select "html[lang=es]"
  end

  test "LC-3 missing and empty browser entries render English without an error" do
    [ {}, { "Accept-Language" => ",,;q=," } ].each do |headers|
      get "/about", headers: headers
      assert_response :success
      assert_language "en"
    end
  end

  private
    def assert_language(code, message = nil)
      assert_select "html[lang=?]", code, message: [ message, "page in #{code}" ].compact.join(": ")
    end
end
