require "test_helper"

class LocaleUrlsContractTest < ActionDispatch::IntegrationTest
  PAGES = %w[/ /about /work /contact /consulting /writing /writing/published-post].freeze

  test "LC-7 counterpart retains raw query without turning it into URL options" do
    query = "ref=a%2Fb&host=evil.example&protocol=https&only_path=false&locale=es&ref=c+d"
    patch "/locale", params: { locale: "en" }, headers: { "Referer" => "http://www.example.com/es/about?#{query}" }
    assert_response :see_other
    assert_redirected_to "http://www.example.com/en/about?#{query}"
    assert_equal "en", cookies["locale"]
    follow_redirect!
    assert_select "html[lang=en]"
  end

  test "LC-7 root-relative public referrers and unknown post slugs are rebuilt" do
    { "/about?ref=x" => "/es/about?ref=x", "/writing/nope" => "/es/writing/nope",
      "/en/feed.xml?ref=x" => "/es/feed.xml?ref=x", "/" => "/es" }.each do |referer, destination|
      patch "/locale", params: { locale: "es" }, headers: { "Referer" => referer }
      assert_response :see_other
      assert_redirected_to "http://www.example.com#{destination}"
    end
    get "/es/writing/nope"
    assert_response :not_found
  end

  {
    "missing" => nil, "foreign" => "http://evil.example/about", "protocol-relative foreign" => "//evil.example/about",
    "protocol-relative local" => "//www.example.com/about", "userinfo" => "http://user@www.example.com/about",
    "port" => "http://www.example.com:8443/about", "scheme" => "ftp://www.example.com:80/about",
    "malformed" => "garbage ://", "unknown" => "/missing", "admin" => "/admin", "control" => "/locale",
    "session" => "/session", "password" => "/passwords/new", "health" => "/up"
  }.each do |label, referer|
    test "LC-8 #{label} referrer falls back to chosen-language home" do
      patch "/locale", params: { locale: "es" }, headers: { "Referer" => referer }.compact
      assert_response :see_other
      assert_redirected_to "http://www.example.com/es"
    end
  end

  test "LC-8 Rails refuses open redirects by default" do
    assert_equal :raise, ActionController::Base.action_on_open_redirect
  end

  test "LC-8 either HTTP scheme works on the request port" do
    patch "/locale", params: { locale: "en" }, headers: { "Referer" => "https://www.example.com:80/es/contact" }
    assert_redirected_to "http://www.example.com/en/contact"
  end

  test "LC-9 invalid choices preserve the original safe path locale and raw query" do
    [ "fr", "ES", "", nil ].each do |choice|
      cookies[:locale] = "en"
      [ "/es/about?locale=en", "/en/about?ref=x", "/about?ref=a%2Fb" ].each do |referer|
        patch "/locale", params: { locale: choice }.compact, headers: { "Referer" => referer }
        assert_response :see_other
        assert_redirected_to "http://www.example.com#{referer}"
        assert_equal "en", cookies["locale"]
        refute Array(response.headers["Set-Cookie"]).any? { |cookie| cookie.start_with?("locale=") }
      end
      patch "/locale", params: { locale: choice }.compact, headers: { "Referer" => "/admin" }
      assert_redirected_to "http://www.example.com/"
    end
  end

  { "unknown" => { locale: "fr" }, "missing" => {}, "array" => { locale: [ "es" ] } }.each do |label, choice|
    { "//about" => "/about", "//es/about" => "/es/about" }.each do |raw_path, target|
      test "LC-9 #{label} choice rebuilds #{raw_path} at its own locale" do
        cookies[:locale] = "en"
        patch "/locale", params: choice, headers: { "Referer" => "http://www.example.com#{raw_path}" }
        assert_response :see_other
        assert_redirected_to "http://www.example.com#{target}"
        assert_equal "en", cookies["locale"]
        refute Array(response.headers["Set-Cookie"]).any? { |cookie| cookie.start_with?("locale=") }
      end
    end
  end

  { "/session/new" => "/session", "/passwords/new" => "/passwords" }.each do |path, action|
    test "LC-20 LC-21 #{path} keeps plain auth metadata and unscoped links" do
      cookies[:locale] = "es"
      get path, params: { locale: "es" }
      assert_response :success
      assert_select "head link[hreflang]", count: 0
      assert_select 'head meta[property="og:locale"], head meta[property="og:locale:alternate"]', count: 0
      canonical = "http://www.example.com#{path}"
      assert_select "head link[rel=canonical][href=?]", canonical, count: 1
      assert_select 'head meta[property="og:url"][content=?]', canonical, count: 1
      css_select("head [href], head [src], head meta[property='og:url']").each do |node|
        refute_match(/(?:[?&])locale=/, node["href"] || node["src"] || node["content"])
      end
      assert_select "form[action=?]", action, count: 1
      assert_select 'a[href="/passwords/new"]', count: 1 if path == "/session/new"
      assert_select 'a[href*="?locale="], form[action*="?locale="]', count: 0
    end
  end

  test "LC-11 footer round trip changes the address and keeps a misleading query" do
    get "/about?locale=es"
    [ [ "es", "Español" ], [ "en", "English" ] ].each do |locale, label|
      form = css_select("footer form").find { |node| node.at_css("button").text == label }
      fields = form.css("input").to_h { |input| [ input["name"], input["value"] ] }
      post form["action"], params: fields, headers: { "Referer" => request.url }
      assert_redirected_to "http://www.example.com/#{locale}/about?locale=es"
      follow_redirect!
      assert_select "html[lang=?]", locale
      nav_links = css_select(".site-header nav a").map { |node| node["href"] }
      assert_equal 5, nav_links.size
      nav_links.each do |href|
        assert_match(%r{\A/#{locale}(?:/|\z)}, href)
        get href
        assert_response :success
        assert_select "html[lang=?]", locale
      end
      get "/#{locale}/about?locale=es"
    end
  end

  test "LC-18 every public address fixes its language despite conflicting inputs" do
    %w[en es].each do |locale|
      opposite = locale == "en" ? "es" : "en"
      cookies[:locale] = opposite
      PAGES.each do |path|
        get "#{prefixed(locale, path)}?locale=#{opposite}", headers: { "Accept-Language" => opposite }
        assert_response :success
        assert_select "html[lang=?]", locale
      end
      get "/#{locale}/feed?locale=#{opposite}", headers: { "Accept-Language" => opposite }
      assert_response :success
      assert_equal locale, xml_language(Nokogiri::XML(response.body).root)
    end
    get "/about?locale=es", headers: { "Accept-Language" => "es" }
    assert_select "html[lang=en]"
    %w[/fr /fr/about /ES/about /en/admin /es/session /en/passwords/new /es/up].each do |path|
      get path
      assert_response :not_found
    end
    patch "/es/locale", params: { locale: "es" }
    assert_response :not_found
  end

  test "LC-18 LC-21 Copy previews name both languages while View site remains bare" do
    sign_in_as users(:one)
    get "/admin/copy"
    assert_select 'a[href="/en"]', text: "View English"
    assert_select 'a[href="/es"]', text: "View Spanish"
    assert_select 'a[href="/"]', text: /View site/
    assert_select "html[lang=en]"
  end

  test "LC-19 fresh HTML and Atom responses are private and bare addresses vary in place" do
    existing_vary = -> { response.headers["Vary"] = "Accept-Encoding" }
    SiteController.before_action(existing_vary)
    begin
      %w[en es].each do |locale|
        cookies[:locale] = locale
        (PAGES + [ "/feed", "/feed.xml", "/feed.atom" ]).each do |path|
          [ path, prefixed(locale, path) ].each do |address|
            get address
            assert_response :success
            assert_includes response.headers["Cache-Control"].split(/,\s*/), "private", address
            vary = response.headers["Vary"].to_s.split(/,\s*/)
            assert_includes vary, "Accept-Encoding"
            assert_equal address == path, vary.include?("Accept-Language"), address
            assert_nil response.headers["Location"]
          end
        end
      end
    ensure
      SiteController.skip_before_action(existing_vary)
    end
  end

  test "LC-20 each representation has reciprocal metadata and a language canonical" do
    PAGES.each do |path|
      %w[en es].each do |locale|
        cookies[:locale] = locale
        [ path, prefixed(locale, path) ].each do |address|
          (address == path ? [ locale ] : %w[en es]).each do |cookie|
            cookies[:locale] = cookie
            get "#{address}?ref=x&locale=bogus"
            canonical = "http://www.example.com#{prefixed(locale, path)}"
            assert_select "link[rel=canonical][href=?]", canonical, count: 1
            assert_select 'meta[property="og:url"][content=?]', canonical, count: 1
            assert_select 'meta[property="og:locale"][content=?]', locale == "en" ? "en_US" : "es_AR"
            assert_select 'meta[property="og:locale:alternate"][content=?]', locale == "en" ? "es_AR" : "en_US"
            assert_select "link[hreflang]", count: 3
            %w[en es].each do |other|
              assert_select "link[rel=alternate][hreflang=?][href=?]", other, "http://www.example.com#{prefixed(other, path)}", count: 1
            end
            assert_select "link[rel=alternate][hreflang=x-default][href=?]", "http://www.example.com#{path}", count: 1
          end
        end
      end
    end
  end

  test "LC-22 post content declares English when HTML or Atom renders another language" do
    %w[en es].each do |locale|
      cookies[:locale] = locale
      [ "/writing/published-post", "/#{locale}/writing/published-post" ].each do |address|
        get address
        %w[.post__title article\ .prose].each do |selector|
          locale == "es" ? assert_equal("en", css_select(selector).first["lang"]) : assert_nil(css_select(selector).first["lang"])
        end
      end
      [ "/feed", "/#{locale}/feed" ].each do |address|
        get address
        %w[title summary content].each do |element|
          node = Nokogiri::XML(response.body).at_xpath("//*[local-name()='entry']/*[local-name()='#{element}']")
          assert node, element
          locale == "es" ? assert_equal("en", xml_language(node)) : assert_nil(xml_language(node))
        end
      end
    end
  end

  test "LC-12 LC-14 LC-15 LC-17 fixed addresses preserve negotiated prose and fallback semantics" do
    sections(:home_intro).update!(heading_es: "Introducción", note_es: "", body_es: nil)
    SiteSetting["tagline_es"] = " "
    %w[en es].each do |locale|
      cookies[:locale] = locale
      PAGES.each do |path|
        get path
        prose = css_select("main").text.squish
        fallback = css_select("main [lang]").map { |node| [ node.name, node["lang"], node.text.squish ] }
        get prefixed(locale, path), headers: { "Accept-Language" => locale == "en" ? "es" : "en" }
        assert_response :success
        assert_select "html[lang=?]", locale
        assert_equal prose, css_select("main").text.squish
        assert_equal fallback, css_select("main [lang]").map { |node| [ node.name, node["lang"], node.text.squish ] }
      end
    end
  end

  test "LC-23 feed URLs and identities are explicit stable and localised" do
    ids = []
    %w[en es].each do |locale|
      cookies[:locale] = locale
      [ "/feed", "/feed.xml?ref=x", "/feed.atom?ref=z", "/#{locale}/feed", "/#{locale}/feed.xml?ref=w", "/#{locale}/feed.atom?ref=y" ].each do |address|
        get address
        assert_response :success
        feed = feed_document
        assert_equal "http://www.example.com/#{locale}/writing", feed.at_css('feed > link[rel="alternate"]')["href"]
        assert_equal "http://www.example.com/#{locale}/feed", feed.at_css('feed > link[rel="self"]')["href"]
        assert_equal "tag:www.example.com,2005:#{locale == 'en' ? '/feed' : '/es/feed'}", feed.at_css("feed > id").text
        assert_equal "http://www.example.com/#{locale}/writing/published-post", feed.at_css('entry link[rel="alternate"]')["href"]
        ids << feed.css("entry > id").map(&:text)
      end
    end
    assert_equal 1, ids.uniq.size
    assert_match(/Post\/#{posts(:published_post).id}\z/, ids.first.first)
  end

  private
    def prefixed(locale, path)
      path == "/" ? "/#{locale}" : "/#{locale}#{path}"
    end

    def feed_document
      Nokogiri::XML(response.body) { |config| config.strict }.remove_namespaces!
    end

    def xml_language(node)
      node.attribute_with_ns("lang", "http://www.w3.org/XML/1998/namespace")&.value
    end
end

class LocalizedLinksContractTest < ActionView::TestCase
  cover "LocalizedLinksHelper*" if respond_to?(:cover)
  cover "LocalizedLinksHelper#public_page_path" if respond_to?(:cover)
  tests LocalizedLinksHelper

  test "LC-21 malformed local hrefs remain unchanged without damaging sanitised markup" do
    html = '<p><a href="/bad[">unknown</a> <strong>safe</strong></p>'
    fragment = Nokogiri::HTML5.fragment(localized_links(html))
    assert_equal "/bad[", fragment.at_css("a")["href"]
    assert_equal "safe", fragment.at_css("strong").text
  end

  test "LC-21 rebuilt public paths are local and preserve nondefault feed formats" do
    { "/" => "/es", "/feed" => "/es/feed", "/feed.atom" => "/es/feed",
      "/en/feed.xml" => "/es/feed.xml", "/writing/nope" => "/es/writing/nope" }.each do |path, expected|
      assert_equal expected, public_page_path(path, locale: :es)
    end
    %w[/up /session/new /passwords/new /admin /locale /unknown /bad%ZZ].each do |path|
      assert_nil public_page_path(path, locale: :es)
    end
  end
end

class LocaleAuthoredLinksContractTest < ActionDispatch::IntegrationTest
  cover "LocalizedLinksHelper*" if respond_to?(:cover)

  test "LC-21 authored public links localise only their path and never their storage" do
    links = [ "/consulting?host=evil.example&ref=a%2Fb#talk", "/en/about?ref=c+d#bio", "/", "/es/feed.xml?ref=x#feed",
      "/writing/published-post", "//evil.example/about", "https://www.example.com/about", "mailto:a@example.com",
      "about", "#note", "/admin", "/session/new", "/passwords/new", "/locale", "/up", "/no-route", "/bad%ZZ" ]
    body = links.each_with_index.map { |href, index| "[link #{index}](#{href})" }.join("\n\n")
    section = sections(:home_intro)
    section.update!(body: body, body_es: body)
    posts(:published_post).update!(body: body)
    [ [ "/es", "es" ], [ "/", "es" ], [ "/en", "en" ] ].each do |address, locale|
      cookies[:locale] = "es"
      get address
      expected = links.dup
      expected[-1] = "/bad%25ZZ" # Commonmarker escapes the malformed percent before localisation.
      expected[0, 5] = [ "/#{locale}/consulting?host=evil.example&ref=a%2Fb#talk", "/#{locale}/about?ref=c+d#bio",
        "/#{locale}", "/#{locale}/feed.xml?ref=x#feed", "/#{locale}/writing/published-post" ]
      assert_equal expected, css_select("#home_intro .prose a").map { |a| a["href"] }
      get "/#{locale}/writing/published-post"
      assert_equal expected, css_select("article .prose a").map { |a| a["href"] }
      get "/#{locale}/feed"
      content = feed_document.at_css("entry content").text
      assert_equal expected, Nokogiri::HTML5.fragment(content).css("a").map { |a| a["href"] }
    end
    assert_equal body, section.reload.body
    assert_equal body, section.body_es
    assert_equal body, posts(:published_post).reload.body
  end

  private
    def feed_document
      Nokogiri::XML(response.body) { |config| config.strict }.remove_namespaces!
    end
end

class LocaleMetadataContractTest < ActionDispatch::IntegrationTest
  cover "LocalizedLinksHelper#localized_page_url" if respond_to?(:cover)
  cover "LocalizedLinksHelper#open_graph_locale" if respond_to?(:cover)

  test "LC-20 head metadata uses the path language over cookie and query" do
    %w[en es].each do |locale|
      cookies[:locale] = locale == "en" ? "es" : "en"
      get "/#{locale}/about?locale=bogus"
      assert_select "link[rel=canonical][href=?]", "http://www.example.com/#{locale}/about", count: 1
      assert_select 'meta[property="og:locale"][content=?]', locale == "en" ? "en_US" : "es_AR"
      assert_select 'meta[property="og:locale:alternate"][content=?]', locale == "en" ? "es_AR" : "en_US"
      %w[en es].each do |other|
        assert_select "link[hreflang=?][href=?]", other, "http://www.example.com/#{other}/about", count: 1
      end
      assert_select 'link[hreflang="x-default"][href="http://www.example.com/about"]', count: 1
    end
  end
end
