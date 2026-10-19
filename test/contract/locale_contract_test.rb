require "test_helper"

# The language's Contract, as tests. Each test is named after an obligation in
# docs/contracts/locale.md and asserts only on HTTP: the status, the redirect,
# the cookie and the rendered HTML, except LC-5 and LC-13, which read the
# locale files and the templates. LC-1 to LC-5 decide which language a page is
# in; LC-6 to LC-11 are the footer control; LC-12 to LC-16 are what a page in
# Spanish reads.
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

  # --- What a page in Spanish reads -------------------------------------------

  test "LC-12 no page in Spanish shows a string the locale files give in English" do
    cookies[:locale] = "es"
    published = posts(:published_post)
    # Each page, by the heading that says which page it is.
    pages = I18n.with_locale(:es) do
      { root_path => MarkdownRenderer.unmark(SiteSetting.localized("tagline")), about_path => I18n.t("nav.about"), work_path => I18n.t("nav.work"),
        contact_path => I18n.t("nav.contact"), consulting_path => SiteSetting.localized("consulting_heading"), posts_path => I18n.t("nav.writing"), post_path(published) => published.title }
    end

    pages.each do |path, heading|
      get path
      assert_response :success, path
      assert_language "es", path
      assert_select "main h1", { count: 1, text: heading }, path
      assert_no_english_chrome visible_text(response.parsed_body), path
    end
    assert_no_english_chrome atom_feed("es").text, "the feed"
  end

  test "LC-12 nor does Writing with nothing published" do
    Post.update_all(status: :draft, published_at: nil)
    cookies[:locale] = "es"

    get posts_path

    assert_response :success
    assert_language "es"
    assert_no_english_chrome visible_text(response.parsed_body), posts_path
    assert_select "main", text: /Muy pronto, los primeros ensayos/
  end

  test "LC-13 no public template holds a word of its own outside the proper nouns" do
    templates = Pathname.glob(Rails.root.join("app/views/{home,pages,posts,shared}/**/*.{erb,builder}")) << Rails.root.join("app/views/layouts/application.html.erb")
    assert_operator templates.size, :>, 10
    assert_includes templates, Rails.root.join("app/views/posts/feed.atom.builder")

    templates.each do |template|
      words = literal_words(template.read, ruby: template.extname == ".builder")
      assert_empty words - PROPER_NOUNS, "#{template.relative_path_from(Rails.root)} writes these itself instead of through t()"
    end
  end

  test "LC-13 the scan finds a word in text, in a labelling attribute and in a Ruby string" do
    assert_equal %w[ Hello ], literal_words("<p>Hello <%= name %></p>")
    assert_equal %w[ Close ], literal_words(%(<button aria-label="Close"></button>))
    assert_equal %w[ Elsewhere ], literal_words(%(<%= link_to "Elsewhere", root_path, class: "nav-link" %>))
    assert_equal %w[ About ], literal_words(%(<% content_for :title, "About · \#{site}" %>))
    assert_empty literal_words(%(<p class="muted"><%= t("nav.about") %> · <%= link_to "GitHub", url %></p>)) - PROPER_NOUNS
    assert_equal %w[ All ], literal_words(%(feed.rights("All rights reserved")), ruby: true)
    assert_empty literal_words(%(feed.title(t("posts.feed_title", name: SiteSetting["site_title"]))), ruby: true)
  end

  test "LC-14 a section shows its Spanish heading, note and body on a Spanish page" do
    sections(:home_intro).update!(heading_es: "Introducción", note_es: "Una nota al margen.", body_es: "Hola desde ==inicio==.")

    get root_path
    assert_select "#home_intro h2", text: "Intro"
    assert_select "#home_intro .note", text: "A note in the margin."
    assert_select "#home_intro .prose mark", text: "home"

    cookies[:locale] = "es"
    get root_path
    assert_select "#home_intro h2:not([lang])", text: "Introducción"
    assert_select "#home_intro .note:not([lang])", text: "Una nota al margen."
    assert_select "#home_intro .prose:not([lang]) mark", text: "inicio"
    assert_select "#home_intro [lang]", 0
  end

  test "LC-14 a Spanish field left blank shows the English, marked as English" do
    sections(:home_intro).update!(heading_es: "Introducción", note_es: "", body_es: nil)
    cookies[:locale] = "es"

    get root_path

    assert_select "#home_intro h2:not([lang])", text: "Introducción"
    assert_select "#home_intro .note[lang=en]", text: "A note in the margin."
    assert_select "#home_intro .prose[lang=en] mark", text: "home"
  end

  test "LC-14 an English page never shows Spanish, nor marks its own language" do
    sections(:home_intro).update!(heading_es: "Introducción", note_es: "Una nota al margen.", body_es: "Hola.")

    get root_path

    assert_select "#home_intro h2", text: "Intro"
    assert_select "#home_intro [lang]", 0
    assert_no_match(/Introducción|Una nota al margen/, response.body)
  end

  test "LC-15 dates read in the page's language" do
    published = posts(:published_post)
    published.update!(published_at: Time.zone.local(2026, 10, 19, 12))

    { "en" => [ "Oct 19, 2026", "October 19, 2026" ], "es" => [ "19 oct 2026", "19 de octubre de 2026" ] }.each do |locale, (listed, dated)|
      cookies[:locale] = locale
      get root_path
      assert_select ".post-list__date", text: listed
      get posts_path
      assert_select ".post-list__date", text: listed
      get post_path(published)
      assert_select ".post__meta time", text: dated
    end
  end

  test "LC-15 the feed declares the page's language and reads in it" do
    SiteSetting["tagline_es"] = "Construye ==software== cuidadoso."

    cookies[:locale] = "en"
    assert_equal "Writing by Test Site", atom_feed("en").remove_namespaces!.at("feed > title").text

    cookies[:locale] = "es"
    feed = atom_feed("es").remove_namespaces!
    assert_equal "Escritos de Test Site", feed.at("feed > title").text
    assert_equal "Construye software cuidadoso.", feed.at("feed > subtitle").text
  end

  test "LC-16 the admin's section form edits the Spanish heading, note and body" do
    sign_in_as users(:one)
    section = sections(:home_intro)

    patch admin_section_path(section), params: { section: { heading_es: "Introducción", note_es: "Al margen.", body_es: "Hola." } }
    assert_redirected_to admin_sections_path
    assert_equal [ "Introducción", "Al margen.", "Hola." ], section.reload.values_at(:heading_es, :note_es, :body_es)

    get edit_admin_section_path(section)
    assert_select "input[name='section[heading_es]'][value=?]", "Introducción"
    assert_select "input[name='section[note_es]'][value=?]", "Al margen."
    assert_select "textarea[name='section[body_es]']", text: "Hola."
  end

  private
    PROPER_NOUNS = %w[ English Español GitHub LinkedIn ].freeze

    # Every English string in en.yml whose Spanish twin differs, cut at its
    # placeholders (%{name}, %b) into the pieces that are words.
    def english_chrome
      en = leaves(YAML.load_file(Rails.root.join("config/locales/en.yml")).fetch("en"))
      es = leaves(YAML.load_file(Rails.root.join("config/locales/es.yml")).fetch("es"))
      en.reject { |path, value| es[path] == value }.values.flat_map do |value|
        value.split(/%\{\w+\}|%-?\w/).map(&:strip).grep(/\p{L}{2}/)
      end.uniq
    end

    def assert_no_english_chrome(text, where)
      found = english_chrome.select { |english| text.match?(/(?<!\p{L})#{Regexp.escape(english)}(?!\p{L})/) }
      assert_empty found, "English chrome on #{where} in Spanish"
    end

    # What a reader gets from a page: its text, outside scripts, and the
    # attributes that name things to a screen reader or a link preview.
    def visible_text(page)
      text = page.xpath("//text()[not(ancestor::script) and not(ancestor::style)]").map(&:text)
      labels = page.xpath("//@aria-label | //@title | //@alt | //@placeholder | //meta[@name='description' or @property='og:title' or @property='og:description']/@content").map(&:value)
      (text + labels).join("\n")
    end

    # The feed at the request's locale, after asserting it is an Atom feed that
    # declares that language as xml:lang, not as a lang of no namespace.
    def atom_feed(code)
      get feed_path
      assert_response :success
      feed = Nokogiri::XML(response.body) { |config| config.strict }
      assert_equal [ "http://www.w3.org/2005/Atom", "feed" ], [ feed.root.namespace&.href, feed.root.name ]
      assert_equal code, feed.root.attribute_with_ns("lang", "http://www.w3.org/XML/1998/namespace")&.value, "xml:lang"
      feed
    end

    # The words a template writes itself: in its markup's text and labelling
    # attributes, and capitalised in the string literals of its Ruby. A Builder
    # template (ruby: true) is all Ruby.
    def literal_words(source, ruby: false)
      return capitalised_words(Prism.parse(source).value) if ruby

      source = source.gsub(/<%#.*?%>/m, "").gsub(/<%= javascript_tag.*?<% end %>/m, "")
      markup = Nokogiri::HTML5(source.gsub(/<%.*?%>/m, "·"))
      text = markup.xpath("//text() | //@aria-label | //@title | //@alt | //@placeholder").map { |node| node.text }
      ruby = Prism.parse(source.scan(/<%=?(.*?)-?%>/m).flatten.join("\n")).value
      text.flat_map { |string| string.scan(/\p{L}{2,}/) } + capitalised_words(ruby)
    end

    def capitalised_words(ruby)
      strings_in(ruby).flat_map { |string| string.scan(/\p{Lu}\p{L}+/) }
    end

    def strings_in(node)
      own = node.is_a?(Prism::StringNode) ? [ node.unescaped ] : []
      own + node.compact_child_nodes.flat_map { |child| strings_in(child) }
    end

    def leaves(value, path = nil)
      case value
      when Hash then value.reduce({}) { |all, (key, child)| all.merge(leaves(child, [ path, key ].compact.join("."))) }
      when Array then value.each_with_index.reduce({}) { |all, (child, index)| all.merge(leaves(child, "#{path}.#{index}")) }
      when String then { path => value }
      else {}
      end
    end
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

class CopyLocaleContractTest < ActionDispatch::IntegrationTest
  cover "SiteSetting*" if respond_to?(:cover)

  test "LC-17 every saved blank Spanish copy field declares English fallback" do
    Section.delete_all
    Post.delete_all
    cases = {
      "tagline" => [ "/", ".hero h1" ], "hero_note" => [ "/", ".hero .note" ],
      "work_intro" => [ "/work", ".page__header p" ], "writing_intro" => [ "/writing", ".page__header p" ],
      "footer_pitch" => [ "/contact", ".site-footer__cta" ], "consulting_heading" => [ "/consulting", "main h1" ],
      "consulting_contact" => [ "/consulting", "main > .page > p" ], "about_empty" => [ "/about", "main .muted" ],
      "work_empty" => [ "/work", "main .rail-indent.muted" ], "writing_empty" => [ "/writing", "main .rail-indent.muted" ]
    }
    cases.each_key { |key| SiteSetting["#{key}_es"] = " \n " }
    cookies[:locale] = "es"
    cases.each do |key, (path, selector)|
      get path
      english = SiteSetting::DEFAULTS.fetch(key).gsub("%{consulting_link}", "consulting").gsub("%{linkedin_link}", "LinkedIn")
      assert_select "#{selector}[lang=en]", 1, key
      assert_select selector, text: english, count: 1
    end
    get contact_path
    assert_select ".site-footer__cta[lang=en] a", text: "consulting"
    cookies[:locale] = "en"
    cases.each_value do |path, selector|
      get path
      assert_select "#{selector}[lang]", 0
    end
    # The form preserves a deliberate blank, while ordinary settings retain
    # their existing blank-means-default rule.
    sign_in_as users(:one)
    get "/admin/copy"
    assert_select 'textarea[name="copy[tagline_es]"]', text: " \n "
    SiteSetting["email"] = " "
    assert_equal SiteSetting::DEFAULTS.fetch("email"), SiteSetting["email"]
  end
end
