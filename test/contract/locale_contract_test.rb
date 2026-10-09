require "test_helper"

# The language's Contract, as tests. Each test is named after an obligation in
# PRODUCT.md ("Contract: the language") and asserts only on HTTP: the status,
# the redirect, the cookie and the rendered HTML. LC-1 to LC-5 decide which
# language a page is in; LC-6 to LC-11 are the footer control.
class LocaleContractTest < ActionDispatch::IntegrationTest
  cover "SiteController*" if respond_to?(:cover)
  cover "LocalesController*" if respond_to?(:cover)

  # --- Which language a page is in -------------------------------------------

  test "LC-1 a locale cookie naming a site language decides, whatever the browser asks for" do
    cookies[:locale] = "es"
    get about_path, headers: { "Accept-Language" => "en" }
    assert_language "es"

    cookies[:locale] = "en"
    get about_path, headers: { "Accept-Language" => "es" }
    assert_language "en"
  end

  test "LC-1 the cookie decides on every public page" do
    cookies[:locale] = "es"

    [ root_path, about_path, work_path, contact_path, posts_path, post_path(posts(:published_post)) ].each do |path|
      get path
      assert_language "es", path
    end
  end

  test "LC-2 without the cookie, the first entry the browser sent in a site language decides" do
    [ "fr-FR, es-AR;q=0.9, en;q=0.8", "fr-FR,es;q=0.9" ].each do |header|
      get about_path, headers: { "Accept-Language" => header }

      assert_language "es", header
    end
  end

  test "LC-2 the region and the case of an entry are ignored" do
    get about_path, headers: { "Accept-Language" => "ES-ar" }

    assert_language "es"
  end

  test "LC-2 the whole language subtag must name a site language" do
    get about_path, headers: { "Accept-Language" => "esu, en" }

    assert_language "en"
  end

  test "LC-2 entries are taken in the order sent, not re-sorted by q" do
    get about_path, headers: { "Accept-Language" => "en;q=0.1, es;q=0.9" }

    assert_language "en"
  end

  test "LC-3 with neither, the page is in English" do
    get about_path

    assert_language "en"
  end

  test "LC-3 a browser asking only for languages the site lacks gets English" do
    get about_path, headers: { "Accept-Language" => "fr-FR, de;q=0.9" }

    assert_language "en"
  end

  test "LC-3 an unknown cookie is skipped, and the browser decides" do
    cookies[:locale] = "fr"
    get about_path, headers: { "Accept-Language" => "es" }
    assert_language "es"

    get about_path
    assert_language "en"
  end

  test "LC-3 a malformed header renders the page in English" do
    [ "*", ",,;q=,", "e", "1234" ].each do |header|
      get about_path, headers: { "Accept-Language" => header }

      assert_response :success, header
      assert_language "en", header
    end
  end

  test "LC-4 login and password reset are in English whatever the visitor chose" do
    cookies[:locale] = "es"

    [ new_session_path, new_password_path ].each do |path|
      get path, headers: { "Accept-Language" => "es" }
      assert_language "en", path
    end
  end

  test "LC-4 the admin is in English and offers no language control" do
    cookies[:locale] = "es"
    sign_in_as users(:one)

    [ admin_root_path, admin_site_settings_path ].each do |path|
      get path, headers: { "Accept-Language" => "es" }

      assert_language "en", path
      assert_select "form[action='/locale']", 0, path
    end
  end

  test "LC-5 the two locale files have the same tree of keys" do
    en = flatten(YAML.load_file(Rails.root.join("config/locales/en.yml")).fetch("en"))
    es = flatten(YAML.load_file(Rails.root.join("config/locales/es.yml")).fetch("es"))

    assert_empty en - es, "missing from es.yml"
    assert_empty es - en, "in es.yml but not en.yml"
  end

  # --- Choosing a language ----------------------------------------------------

  test "LC-6 PATCH /locale sets the cookie to the code" do
    %w[ es en ].each do |code|
      patch "/locale", params: { locale: code }

      assert_equal code, cookies["locale"], code
    end
  end

  test "LC-6 the cookie outlives the browser session and is SameSite=Lax and HttpOnly" do
    patch "/locale", params: { locale: "es" }

    set_cookie = locale_set_cookie
    assert set_cookie, "a locale cookie is set"
    assert_match(/expires=/i, set_cookie, "a permanent cookie, not a session one")
    assert_operator expiry(set_cookie), :>, 1.year.from_now
    assert_match(/samesite=lax/i, set_cookie)
    assert_match(/;\s*httponly/i, set_cookie, "no script reads it")
  end

  test "LC-7 it answers 303 back to the page the request came from, query kept" do
    referer = "http://www.example.com/writing/published-post?ref=feed"
    patch "/locale", params: { locale: "es" }, headers: { "Referer" => referer }

    assert_response :see_other
    assert_redirected_to referer
  end

  test "LC-8 with no referrer it goes home" do
    patch "/locale", params: { locale: "es" }

    assert_response :see_other
    assert_redirected_to root_url
  end

  test "LC-8 a referrer on another host goes home" do
    patch "/locale", params: { locale: "es" }, headers: { "Referer" => "https://evil.example/phish" }

    assert_response :see_other
    assert_redirected_to root_url
  end

  test "LC-9 an unknown, blank or missing code sets no cookie and still redirects back" do
    referer = "http://www.example.com/about"

    [ { locale: "fr" }, { locale: "ES" }, { locale: "" }, {} ].each do |params|
      patch "/locale", params: params, headers: { "Referer" => referer }

      assert_response :see_other, params.inspect
      assert_redirected_to referer
      assert_nil locale_set_cookie, "#{params.inspect} sets no locale cookie"
    end
  end

  test "LC-9 an unknown code leaves an earlier choice in place" do
    patch "/locale", params: { locale: "es" }
    patch "/locale", params: { locale: "fr" }

    assert_equal "es", cookies["locale"]
    get about_path
    assert_language "es"
  end

  test "LC-10 every public page's footer holds a named group of two language buttons" do
    [ root_path, about_path, work_path, contact_path, posts_path, post_path(posts(:published_post)) ].each do |path|
      get path

      assert_select "footer [role=group][aria-label=Language]", 1, path do
        assert_select "form[action='/locale']", 2, path
      end
    end
  end

  test "LC-10 each button is a plain form that PATCHes /locale with its code, English first" do
    get about_path

    forms = css_select("footer [role=group] form[action='/locale']")
    assert_equal %w[ en es ], forms.map { |form| submitted(form)["locale"] }
    forms.each do |form|
      assert_equal "post", form["method"].to_s.downcase, "works without JavaScript"
      assert_equal "patch", submitted(form)["_method"]
      assert form.at_css("button[type=submit], input[type=submit]"), "a submit button"
    end
  end

  test "LC-10 each button names its language in that language, with lang, whatever the page's language" do
    %w[ en es ].each do |code|
      cookies[:locale] = code
      get about_path

      english, spanish = language_buttons
      assert_equal [ "English", "en" ], [ english&.text&.strip, english&.[]("lang") ], "on a page in #{code}"
      assert_equal [ "Español", "es" ], [ spanish&.text&.strip, spanish&.[]("lang") ], "on a page in #{code}"
    end
  end

  test "LC-10 the group is named in the page's language" do
    cookies[:locale] = "es"
    get about_path

    assert_select "footer [role=group][aria-label=Idioma]", 1
  end

  test "LC-10 the current language's button is pressed and the other is not" do
    get about_path
    assert_equal %w[ true false ], language_buttons.map { |button| button["aria-pressed"] }

    cookies[:locale] = "es"
    get about_path
    assert_equal %w[ false true ], language_buttons.map { |button| button["aria-pressed"] }
  end

  test "LC-11 pressing a footer button brings the same page back in that language, and the site stays in it" do
    get about_path
    assert_language "en"

    spanish = css_select("footer [role=group] form[action='/locale']").find { |form| submitted(form)["locale"] == "es" }
    assert spanish, "a Spanish button"
    post spanish["action"], params: submitted(spanish), headers: { "Referer" => "http://www.example.com#{about_path}" }

    assert_redirected_to about_url
    follow_redirect!
    assert_language "es"
    assert_select "nav a", text: "Sobre mí"
    assert_equal %w[ false true ], language_buttons.map { |button| button["aria-pressed"] }

    get posts_path
    assert_language "es"
  end

  private
    def assert_language(code, message = nil)
      assert_select "html[lang=?]", code, message: [ message, "page in #{code}" ].compact.join(": ")
    end

    def language_buttons
      css_select("footer [role=group] form[action='/locale']").map { |form| form.at_css("button, input[type=submit]") }
    end

    # The fields a browser would send when this form's button is pressed:
    # its hidden inputs, plus the button's own name and value.
    def submitted(form)
      fields = form.css("input[type=hidden]").to_h { |input| [ input["name"], input["value"] ] }
      button = form.at_css("button[name], input[type=submit][name]")
      fields[button["name"]] = button["value"] if button
      fields
    end

    def locale_set_cookie
      Array(response.headers["Set-Cookie"]).flat_map { |header| header.split("\n") }.find { |line| line.start_with?("locale=") }
    end

    def expiry(set_cookie)
      Time.httpdate(set_cookie[/expires=([^;]+)/i, 1])
    end

    def flatten(hash, prefix = nil)
      hash.flat_map do |key, value|
        path = [ prefix, key ].compact.join(".")
        value.is_a?(Hash) ? flatten(value, path) : [ path ]
      end
    end
end
