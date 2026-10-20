require "test_helper"

class CopyContractTest < ActionDispatch::IntegrationTest
  cover "SiteSetting*" if respond_to?(:cover)

  # Literal defaults captured from 4d307e9 before moving any copy.
  COPY = {
    "tagline" => [ "/", ".hero h1", "Senior Software Engineer. I build the systems that let agents build good software.", "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software." ],
    "hero_note" => [ "/", ".hero .note", "Thirteen years in audio first. Same job.", "Trece años en audio primero. El mismo trabajo." ],
    "work_intro" => [ "/work", ".page__header p", "Most of my product work is private. Here's the public proof.", "Casi todo mi trabajo de producto es privado. Esta es la prueba pública." ],
    "writing_intro" => [ "/writing", ".page__header p", "Notes on AI-native workflows, agent orchestration, and product-minded engineering.", "Notas sobre flujos de trabajo AI-native, orquestación de agentes e ingeniería con mirada de producto." ],
    "footer_pitch" => [ "/contact", ".site-footer__cta", "Open to roles building agent systems and AI-native products, and to %{consulting_link}.", "Abierto a roles construyendo sistemas de agentes y productos AI-native, y a %{consulting_link}." ],
    "consulting_heading" => [ "/consulting", "main h1", "Agustín Calabrese: agentic development and AI-native systems", "Agustín Calabrese: desarrollo con agentes y sistemas AI-native" ],
    "consulting_contact" => [ "/consulting", "main > .page > p", "Want to talk about your team? Get in touch on %{linkedin_link}.", "¿Querés hablar de tu equipo? Escribime por %{linkedin_link}." ],
    "about_empty" => [ "/about", "main .muted", "About content coming soon.", "Muy pronto, más sobre mí." ],
    "work_empty" => [ "/work", "main .rail-indent.muted", "Projects coming soon.", "Muy pronto, proyectos." ],
    "writing_empty" => [ "/writing", "main .rail-indent.muted", "First essays coming soon.", "Muy pronto, los primeros ensayos." ]
  }.freeze

  TOKENS = { "footer_pitch" => "%{consulting_link}", "consulting_contact" => "%{linkedin_link}" }.freeze

  setup do
    Section.delete_all
    Post.delete_all
  end

  test "CO-1 Copy is linked in the English admin and saves every language pair" do
    sign_in_as users(:one)
    cookies[:locale] = "es"
    get "/admin"
    assert_select 'nav a[href="/admin/copy"]', text: "Copy"
    get "/admin/copy"
    assert_response :success
    assert_select "html[lang=en]"
    COPY.each_key do |key|
      assert_select ".field-row" do
        assert_select "[name=?][lang=en]", "copy[#{key}]"
        assert_select "[name=?][lang=es]", "copy[#{key}_es]"
      end
    end
    values = edited_copy
    patch "/admin/copy", params: { copy: values }
    assert_redirected_to "/admin/copy"
    follow_redirect!
    values.each do |key, value|
      assert_equal value, SiteSetting.find_by!(key: key).value
      assert_select "textarea[name=?]", "copy[#{key}]", text: value
    end
  end

  test "CO-1 Copy uses the existing login requirement for reads and writes" do
    get "/admin/copy"
    assert_redirected_to new_session_path
    before = SiteSetting.pluck(:key, :value).sort
    patch "/admin/copy", params: { copy: { tagline: "Uninvited edit" } }
    assert_redirected_to new_session_path
    assert_equal before, SiteSetting.pluck(:key, :value).sort
  end

  test "CO-2 Copy and Settings each admit only their own keys" do
    sign_in_as users(:one)
    SiteSetting["tagline"] = "Existing hero"
    get admin_site_settings_path
    assert_equal %w[email github_url linkedin_url site_title theme_preset], css_select('[name^="settings["]').map { |field| field["name"][/\[(.*)\]/, 1] }.sort
    patch admin_site_settings_path, params: { settings: { tagline: "Wrong editor", work_intro: "Wrong editor", unknown: "Wrong key", site_title: "Updated title" } }
    assert_equal "Existing hero", SiteSetting["tagline"]
    assert_nil SiteSetting.find_by(key: "work_intro")
    assert_nil SiteSetting.find_by(key: "unknown")
    assert_equal "Updated title", SiteSetting["site_title"]
    patch "/admin/copy", params: { copy: { tagline: "Right editor", site_title: "Wrong editor", unknown: "Wrong key" } }
    assert_equal "Right editor", SiteSetting["tagline"]
    assert_equal "Updated title", SiteSetting["site_title"]
    assert_nil SiteSetting.find_by(key: "unknown")
  end

  test "CO-3 missing rows preserve the literal defaults in both languages without writes" do
    keys = COPY.keys.flat_map { |key| [ key, "#{key}_es" ] }
    SiteSetting.where(key: keys).delete_all
    COPY.each do |key, (path, selector, english, spanish)|
      [ [ "en", english ], [ "es", spanish ] ].each do |locale, source|
        cookies[:locale] = locale
        get path
        assert_response :success
        expected = source.gsub("%{consulting_link}", locale == "en" ? "consulting" : "consultoría").gsub("%{linkedin_link}", "LinkedIn")
        assert_select selector, text: expected
        assert_select "#{selector}[lang]", 0
        assert_equal source, I18n.with_locale(locale) { SiteSetting.localized(key) }
      end
    end
    assert_empty SiteSetting.where(key: keys)
  end

  test "CO-3 the four existing hero rows keep their keys and values" do
    values = { "tagline" => "Existing English", "tagline_es" => "Existente español", "hero_note" => "Existing note", "hero_note_es" => "Nota existente" }
    values.each { |key, value| SiteSetting[key] = value }
    before = SiteSetting.where(key: values.keys).pluck(:key, :value).sort
    sign_in_as users(:one)
    get "/admin/copy"
    values.each { |key, value| assert_select "textarea[name=?]", "copy[#{key}]", text: value }
    assert_equal before, SiteSetting.where(key: values.keys).pluck(:key, :value).sort
  end

  test "CO-3 pre-existing blank Spanish hero rows now show English without changing the rows" do
    english = { "tagline" => "Existing English tagline.", "hero_note" => "Existing English note." }
    english.each { |key, value| SiteSetting[key] = value }
    cookies[:locale] = "es"
    [ "", " \n ", nil ].each do |blank|
      keys = %w[tagline_es hero_note_es]
      SiteSetting.where(key: keys).delete_all
      keys.each do |key|
        SiteSetting.create!(key: key, value: blank, created_at: Time.utc(2026, 10, 18), updated_at: Time.utc(2026, 10, 18))
      end
      before = SiteSetting.where(key: keys).order(:key).pluck(:id, :key, :value, :created_at, :updated_at)
      get root_path
      assert_select ".hero h1[lang=en]", text: english.fetch("tagline")
      assert_select ".hero .note[lang=en]", text: english.fetch("hero_note")
      assert_equal before, SiteSetting.where(key: keys).order(:key).pluck(:id, :key, :value, :created_at, :updated_at)
    end
  end

  test "CO-4 edits in either language reach every public placement" do
    sign_in_as users(:one)
    values = edited_copy
    patch "/admin/copy", params: { copy: values }
    assert_redirected_to "/admin/copy"
    COPY.each do |key, (path, selector)|
      %w[en es].each do |locale|
        cookies[:locale] = locale
        get path
        source = values.fetch(locale == "en" ? key : "#{key}_es")
        expected = source.gsub("%{consulting_link}", locale == "en" ? "consulting" : "consultoría").gsub("%{linkedin_link}", "LinkedIn")
        assert_select selector, text: expected
        assert_select "#{selector}[lang]", 0
      end
    end
  end

  test "CO-5 malformed linked sentences save nothing and retain fields for correction" do
    sign_in_as users(:one)
    TOKENS.each do |key, token|
      [ "Missing link", "#{token} twice #{token}", "%{wrong_link}" ].each do |bad|
        before = SiteSetting.pluck(:key, :value).sort
        patch "/admin/copy", params: { copy: { tagline: "Must not save", key => bad, "#{key}_es" => "Spanish #{token}" } }
        assert_response :unprocessable_entity
        assert_select ".form-errors", text: /#{Regexp.escape(token)}/
        assert_select "textarea[name=?]", "copy[#{key}]", text: bad
        assert_select 'textarea[name="copy[tagline]"]', text: "Must not save"
        assert_equal before, SiteSetting.pluck(:key, :value).sort
      end
    end
  end

  test "CO-5 links keep live destinations and follow the surrounding language" do
    sign_in_as users(:one)
    patch "/admin/copy", params: { copy: { footer_pitch: "Ask about %{consulting_link}.", footer_pitch_es: "Hablamos de %{consulting_link}.", consulting_contact: "Talk on %{linkedin_link}.", consulting_contact_es: "Por %{linkedin_link}." } }
    assert_redirected_to "/admin/copy"
    SiteSetting["linkedin_url"] = "https://www.linkedin.com/in/updated"
    %w[en es].each do |locale|
      cookies[:locale] = locale
      get consulting_path(locale: nil)
      assert_select ".site-footer__cta a[href='/#{locale}/consulting']", text: locale == "en" ? "consulting" : "consultoría"
      assert_select 'main p a[href="https://www.linkedin.com/in/updated"][target="_blank"][rel="noopener"]', text: "LinkedIn"
    end
  end

  test "CO-6 authored markup and entities stay literal in prose fields and metadata" do
    sign_in_as users(:one)
    attack = '<script>alert("x")</script><img src=x onerror=alert(1)> &lt;i&gt; & "quoted"'
    values = COPY.keys.to_h { |key| [ key, "#{attack} #{TOKENS[key]}".strip ] }
    patch "/admin/copy", params: { copy: values }
    assert_redirected_to "/admin/copy"
    get "/admin/copy"
    assert_select "main script, main img", 0
    COPY.each do |key, (path, selector)|
      get path
      assert_select "main script, main img, .site-footer__cta script, .site-footer__cta img", 0
      assert_includes css_select(selector).first.text, attack, key
      assert_select "#{selector} a", TOKENS.key?(key) ? 1 : 0
    end
    get consulting_path(locale: nil)
    assert_equal "#{attack} · Test Site", css_select("title").first.text
    assert_equal "#{attack} · Test Site", css_select('meta[property="og:title"]').first["content"]
    get root_path
    assert_equal attack, css_select('meta[name="description"]').first["content"]
    assert_equal attack, css_select('meta[property="og:description"]').first["content"]
    get feed_path
    feed = Nokogiri::XML(response.body) { |config| config.strict }
    subtitle = feed.at_xpath('//*[local-name()="subtitle"]')
    assert_equal attack, subtitle.text
    assert_empty subtitle.element_children
  end

  test "CO-7 multiline mark fields draw marks including around generated links" do
    sign_in_as users(:one)
    get "/admin/copy"
    (COPY.keys - %w[hero_note consulting_heading]).each do |key|
      assert_select "textarea[name=?]", "copy[#{key}]"
      assert_select "textarea[name=?]", "copy[#{key}_es]"
    end
    values = COPY.keys.to_h { |key| [ key, "First ==careful\n#{TOKENS[key] || 'work'}==." ] }
    patch "/admin/copy", params: { copy: values }
    assert_redirected_to "/admin/copy"
    COPY.each do |key, (path, selector)|
      get path
      if %w[hero_note consulting_heading].include?(key)
        assert_select "#{selector} mark", 0
      else
        assert_select "#{selector} mark", 1
        assert_select "#{selector} mark a", 1 if TOKENS.key?(key)
      end
    end
    get root_path
    assert_equal "First careful\nwork.", css_select('meta[name="description"]').first["content"]
    get feed_path
    assert_equal "First careful\nwork.", Nokogiri::XML(response.body).at_xpath('//*[local-name()="subtitle"]').text
    get consulting_path(locale: nil)
    assert_equal "First careful\nwork. · Test Site", css_select("title").first.text
  end

  private

  def edited_copy
    COPY.keys.each_with_object({}) do |key, values|
      values[key] = "English #{key} #{TOKENS[key]}".strip
      values["#{key}_es"] = "Español #{key} #{TOKENS[key]}".strip
    end
  end
end
