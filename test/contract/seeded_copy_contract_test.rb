require "test_helper"

class SeededCopyContractTest < ActionDispatch::IntegrationTest
  # FillSpanishSections' input, frozen as the seeded Spanish stood on 2026-10-19.
  FROZEN_SPANISH = YAML.load_file(Rails.root.join("db/migrate/20261019120100_fill_spanish_sections.yml")).freeze

  setup do
    # Exercise first-deploy content rather than fixtures that could drift.
    capture_io { load Rails.root.join("db/seeds.rb") }
  end

  test "SC-1 seeded public pages no longer name or link Claude Forge" do
    [ "/", "/about", "/work", "/contact", "/consulting", "/writing", "/feed" ].each do |path|
      get path
      assert_response :success
      assert_no_match(/Claude Forge|ag0os\/claude-forge/i, response.body, "retired toolkit on #{path}")
    end
  end

  test "SC-2 Work links Troupe to its public repository" do
    get "/work"
    assert_response :success
    assert_select '#work_open_source a[href="https://github.com/ag0os/troupe"]', count: 1, text: "Troupe"
  end

  test "SC-3 About bio links to an existing public consulting page" do
    %w[en es].each do |locale|
      cookies[:locale] = locale
      [ "/about", "/#{locale}/about" ].each do |address|
        get address
        assert_response :success
        assert_select "#about_bio a[href='/#{locale}/consulting']", count: 1
        get css_select("#about_bio a[href='/#{locale}/consulting']").first["href"]
        assert_response :success
        assert_select "html[lang=?]", locale
        assert_select "main #consulting_intro"
      end
    end
  end
  { "en" => "consulting", "es" => "consultoría" }.each do |locale, label|
    [ "/", "/about", "/work", "/contact", "/consulting", "/writing", "/writing/published-post" ].each do |path|
      test "SC-5 #{path} footer links #{label} to consulting in #{locale}" do
        cookies[:locale] = locale
        get path
        assert_response :success
        assert_select ".site-footer__cta a[href='/#{locale}/consulting']", count: 1, text: label
      end
    end

    test "SC-5 Contact intro and About bio link to consulting in #{locale}" do
      cookies[:locale] = locale
      { "/contact" => "contact_intro", "/about" => "about_bio" }.each do |path, section|
        get path
        assert_response :success
        assert_select "##{section} a[href=\"/#{locale}/consulting\"]", count: 1
      end
    end
  end

  test "SC-6 the seeds plant no posts" do
    assert_equal posts(:draft_post, :published_post).map(&:id).sort, Post.ids.sort
  end

  test "SC-7 every seeded section has Spanish for each field it has in English, with the same links and marks" do
    only_seeded_sections
    assert_operator Section.count, :>, 10

    Section.find_each do |section|
      %w[ heading note body ].each do |field|
        assert_equal section[field].present?, section["#{field}_es"].present?, "#{section.key}.#{field}_es"
      end
      english, spanish = [ section.body, section.body_es ].map { |body| Nokogiri::HTML5.fragment(MarkdownRenderer.render(body)) }
      assert_equal english.css("a").map { |a| a["href"] }, spanish.css("a").map { |a| a["href"] }, "#{section.key} links"
      assert_equal english.css("mark").size, spanish.css("mark").size, "#{section.key} marks"
    end
  end

  test "SC-7 a seeded page in Spanish shows its Spanish, none of it marked as English" do
    only_seeded_sections
    cookies[:locale] = "es"
    { "/" => "home_what_i_do", "/about" => "about_bio", "/work" => "work_open_source", "/contact" => "contact_intro", "/consulting" => "consulting_intro" }.each do |path, key|
      get path
      assert_select "main [lang]", { count: 0 }, path
      spanish = Nokogiri::HTML5.fragment(MarkdownRenderer.render(Section.find_by!(key: key).body_es))
      assert_equal spanish.text.squish, css_select("##{key} .prose").text.squish, path
    end
  end

  test "SC-7 rendered Spanish public links localise while stored links remain equal" do
    before = Section.order(:id).pluck(:body, :body_es)
    get "/es/about"
    assert_select '#about_bio a[href="/es/consulting"]'
    assert_equal before, Section.order(:id).pluck(:body, :body_es)
  end

  test "SC-8 the migration fills every blank Spanish field of the seeded sections" do
    Section.update_all(heading_es: nil, note_es: nil, body_es: nil)

    migrate :up

    blank = { "heading_es" => nil, "note_es" => nil, "body_es" => nil }
    expected = Section.pluck(:key).to_h { |key| [ key, blank.merge(FROZEN_SPANISH.fetch(key, {})) ] }
    assert_equal expected, Section.all.to_h { |section| [ section.key, section.attributes.slice(*blank.keys) ] }
  end

  test "SC-8 it leaves English, Spanish already written, and other sections as they are" do
    Section.update_all(heading_es: nil, note_es: nil, body_es: nil)
    # The owner's edits in every field, English and Spanish, some emptied or
    # left as whitespace. Blank Spanish is filled; nothing else moves.
    Section.find_by!(key: "home_featured").update!(heading: "Edited heading", note: "", body: "Edited body.",
      heading_es: "Encabezado editado", note_es: "Nota editada.", body_es: "Cuerpo editado.")
    Section.find_by!(key: "home_what_i_do").update!(heading: "  ", note: "Edited note.", body: "",
      heading_es: "", note_es: " \n", body_es: "\t")
    Section.find_by!(key: "about_bio").update!(heading: "Edited bio", note: " ", body: "Edited bio body.",
      heading_es: "Encabezado escrito", note_es: "", body_es: "Cuerpo escrito.")
    before = Section.order(:id).map(&:attributes)
    others = Section.where(key: %w[ home_intro home_hidden ]).map(&:attributes)

    migrate :up

    expected = before.map { |row| row.merge(FROZEN_SPANISH.fetch(row["key"], {}).select { |field, _| row[field].blank? }) }
    assert_equal expected.map { |row| row.except("updated_at") }, Section.order(:id).map { |row| row.attributes.except("updated_at") }
    assert_equal others, Section.where(key: %w[ home_intro home_hidden ]).map(&:attributes)
  end

  test "SC-8 it creates nothing, runs twice cleanly, and rolls back as a no-op" do
    Section.find_by!(key: "about_bio").destroy
    Section.update_all(body_es: nil)
    ids = Section.ids.sort

    migrate :up
    once = Section.order(:id).map(&:attributes)
    migrate :up
    assert_equal once, Section.order(:id).map(&:attributes), "the second run"
    migrate :down
    assert_equal once, Section.order(:id).map(&:attributes), "the rollback"

    assert_nil Section.find_by(key: "about_bio")
    assert_equal ids, Section.ids.sort
  end

  # The approved sentences, as the live site held them on 2026-10-22 and as
  # they read after the swap: [ section key, field ] => [ old, new ].
  SDLC_SECTIONS = {
    [ "home_what_i_do", "body" ] => [
      "I build the systems that let agents build good software: plans and context, orchestration, and the verification that makes the output trustworthy.",
      "I automate the software development lifecycle (SDLC) with agents: plans and context, orchestration, review, and the verification that makes the output trustworthy." ],
    [ "home_what_i_do", "body_es" ] => [
      "Construyo los sistemas que permiten a los agentes construir buen software: planes y contexto, orquestación, y la verificación que hace confiable el resultado.",
      "Automatizo el ciclo de vida del desarrollo de software (SDLC) con agentes: planes y contexto, orquestación, revisión, y la verificación que hace confiable el resultado." ],
    [ "contact_intro", "body" ] => [ "and automate SDLC.", "and automating their SDLC." ],
    [ "about_bio", "body" ] => [ "Buenos Aires Argentina (GMT-3)", "Buenos Aires, Argentina (GMT-3)" ]
  }.freeze
  SDLC_TAGLINES = {
    "tagline" => [ "Senior Software Engineer. I build the systems that let agents build good software.",
      "Senior Software Engineer. I build the systems that let agents build good software, across the whole SDLC." ],
    "tagline_es" => [ "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software.",
      "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software, en todo el ciclo de desarrollo." ]
  }.freeze

  test "SC-9 the migration swaps each approved fragment, stored and rendered" do
    seeded = SDLC_SECTIONS.keys.to_h { |key, field| [ [ key, field ], Section.find_by!(key: key)[field] ] }
    live_before_the_swap
    SDLC_TAGLINES.each { |key, (old, _)| SiteSetting.create!(key: key, value: old) }
    before = stored

    swap :up

    # Only the named content fields move: back to the seeded text, and the
    # saved taglines to the new ones. Timestamps included.
    assert_equal expected_after(before, seeded.merge(SDLC_TAGLINES.to_h { |key, (_, new)| [ [ key, "value" ], new ] })), stored
    pages = { "home_what_i_do" => "", "contact_intro" => "/contact", "about_bio" => "/about" }
    { "en" => [ "tagline", "body" ], "es" => [ "tagline_es", "body_es" ] }.each do |locale, (tagline, field)|
      get "/#{locale}"
      assert_select "main h1", text: SDLC_TAGLINES[tagline].last
      SDLC_SECTIONS.each do |(key, swapped), (old, new)|
        next unless swapped == field
        get "/#{locale}#{pages.fetch(key)}"
        text = css_select("##{key} .prose").text.squish
        assert_includes text, new, "#{key} in #{locale}"
        assert_not_includes text, old, "#{key} in #{locale}"
      end
    end
  end

  test "SC-9 it replaces every exact occurrence and keeps the owner's text around it" do
    # The seeded text holds no old fragment; these two fields hold each twice.
    old, new = SDLC_SECTIONS[[ "about_bio", "body" ]]
    Section.find_by!(key: "about_bio").update!(body: "Owner intro, #{old}.\n\nAgain: #{old}, owner outro.")
    old_tagline, new_tagline = SDLC_TAGLINES["tagline"]
    SiteSetting.create!(key: "tagline", value: "Owner prefix. #{old_tagline} Owner middle. #{old_tagline} Owner suffix.")
    before = stored

    swap :up

    assert_equal expected_after(before,
      [ "about_bio", "body" ] => "Owner intro, #{new}.\n\nAgain: #{new}, owner outro.",
      [ "tagline", "value" ] => "Owner prefix. #{new_tagline} Owner middle. #{new_tagline} Owner suffix."), stored
  end

  test "SC-9 it leaves fields without the exact fragment, other fields, other sections and other settings as they are" do
    seeded_bio = Section.find_by!(key: "about_bio").body
    live_before_the_swap
    home_en, home_es = SDLC_SECTIONS.values_at([ "home_what_i_do", "body" ], [ "home_what_i_do", "body_es" ]).map(&:first)
    # The owner rewrote or emptied some fragments in /admin, kept near-misses
    # of others (a doubled space, an entity, a line break, the other
    # language), and pasted exact fragments where the swap must not look.
    Section.find_by!(key: "home_what_i_do").update!(body: "- #{home_es}", body_es: "- #{home_es.sub(' los ', '  los ')}",
      heading: SDLC_SECTIONS[[ "about_bio", "body" ]].first, note: home_en)
    Section.find_by!(key: "contact_intro").update!(body: "I answer email, and automate&#32;SDLC.", note: "and automate SDLC.", body_es: "and automate SDLC.")
    Section.find_by!(key: "about_bio").update!(body_es: "Buenos Aires Argentina (GMT-3)", note_es: "Buenos Aires Argentina (GMT-3)")
    Section.find_by!(key: "consulting_intro").update!(body: SDLC_SECTIONS.values.map(&:first).join("\n\n"))
    SiteSetting.create!(key: "tagline", value: SDLC_TAGLINES["tagline"].first.sub(" I build", "\nI build"))
    SiteSetting.create!(key: "tagline_es", value: "")
    SiteSetting.create!(key: "hero_note", value: SDLC_TAGLINES["tagline"].first)
    SiteSetting.create!(key: "work_intro_es", value: SDLC_TAGLINES["tagline_es"].first)
    before = stored

    swap :up

    # Only about_bio's English body still held its exact fragment.
    assert_equal expected_after(before, [ "about_bio", "body" ] => seeded_bio), stored
  end

  test "SC-9 with every target present, it runs twice to the same result and rolls back as a no-op" do
    live_before_the_swap
    SDLC_TAGLINES.each { |key, (old, _)| SiteSetting.create!(key: key, value: "#{old} #{old}") }
    before = stored

    swap :up
    once = stored
    assert_not_equal before, once, "the first run"
    swap :up
    assert_equal once, stored, "the second run"
    swap :down
    assert_equal once, stored, "the rollback"
  end

  test "SC-9 it creates nothing where a target is missing" do
    live_before_the_swap
    Section.find_by!(key: "contact_intro").destroy
    ids = Section.ids.sort
    settings = SiteSetting.order(:id).map(&:attributes)

    swap :up
    swap :down

    assert_equal ids, Section.ids.sort
    assert_equal settings, SiteSetting.order(:id).map(&:attributes)
    assert_nil SiteSetting.find_by(key: %w[ tagline tagline_es ])
    get "/en"
    assert_select "main h1", text: SDLC_TAGLINES["tagline"].last
  end

  test "settled taglines describe the home page and its link previews in both languages" do
    SiteSetting.where(key: %w[tagline tagline_es]).delete_all
    { "en" => "Senior Software Engineer. I build the systems that let agents build good software, across the whole SDLC.",
      "es" => "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software, en todo el ciclo de desarrollo." }.each do |locale, tagline|
      cookies[:locale] = locale
      get "/"
      assert_select "main h1", count: 1, text: tagline
      assert_select "main h1 mark", 0
      [ 'meta[name="description"]', 'meta[property="og:description"]' ].each do |selector|
        assert_equal tagline, css_select(selector).first["content"]
      end
    end
  end

  test "settled Featured copy features Shepherd and names Cosmonauts as its predecessor" do
    featured = Section.find_by!(key: "home_featured")
    assert_equal "Shepherd", featured.heading
    assert_equal "Built it because I needed it.", featured.note
    assert_equal <<~MD.strip, featured.body.strip
      **Shepherd** is what I run every day: one agent per project that keeps the context, tracks the work across sessions and runs the other agents, on Claude Code or Codex. I run a flock of them. It lives in Troupe, my agent toolkit.

      [Troupe on GitHub →](https://github.com/ag0os/troupe)

      Before Shepherd I built **Cosmonauts**, an agent orchestration framework with verification inside the pipeline.

      [Cosmonauts on GitHub →](https://github.com/ag0os/cosmonauts)
    MD
    get "/"
    assert_select '#home_featured a[href="https://github.com/ag0os/troupe"]', count: 1
    assert_select '#home_featured a[href="https://github.com/ag0os/cosmonauts"]', count: 1
  end

  test "settled Work copy identifies Cosmonauts as the paused predecessor of Shepherd" do
    assert_equal "- **[Cosmonauts](https://github.com/ag0os/cosmonauts)**. Agent orchestration framework, 2026, the predecessor of Shepherd. Development is paused.",
      Section.find_by!(key: "work_open_source").body.lines.find { |line| line.include?("[Cosmonauts]") }.strip

    get "/work"
    assert_select "#work_open_source li", text: "Cosmonauts. Agent orchestration framework, 2026, the predecessor of Shepherd. Development is paused."
    assert_select '#work_open_source a[href="https://github.com/ag0os/cosmonauts"]', count: 1, text: "Cosmonauts"
  end

  test "settled Contact invitation and localized footer offer roles and consulting" do
    assert_equal <<~MD.strip, Section.find_by!(key: "contact_intro").body.strip
      I'm open to roles building agent systems and AI-native products, and to [consulting](/consulting) for teams adopting agents and automating their SDLC.
      The fastest way to reach me is email, or find me on LinkedIn and GitHub below.
    MD
    { "en" => "Open to roles building agent systems and AI-native products, and to consulting.",
      "es" => "Abierto a roles construyendo sistemas de agentes y productos AI-native, y a consultoría." }.each do |locale, invitation|
      cookies[:locale] = locale
      get "/contact"
      assert_select "#contact_intro a[href='/#{locale}/consulting']", count: 1
      assert_select ".site-footer__cta", text: invitation
    end
  end

  private
    # The fixtures' sections are English only; this leaves just the seeded ones.
    def only_seeded_sections
      Section.delete_all
      capture_io { load Rails.root.join("db/seeds.rb") }
    end

    def migrate(direction)
      load Rails.root.join("db/migrate/20261019120100_fill_spanish_sections.rb").to_s
      ActiveRecord::Migration.suppress_messages { FillSpanishSections.new.migrate(direction) }
    end

    # Puts back the sentences the live site held before the approved swap.
    def live_before_the_swap
      SDLC_SECTIONS.each do |(key, field), (old, new)|
        section = Section.find_by!(key: key)
        assert_includes section[field], new, "the seeded #{key}.#{field}"
        section.update!(field => section[field].sub(new, old))
      end
    end

    # Every stored section and setting, complete, after dating each row in
    # the past, so a write that touches its timestamp shows.
    def stored
      [ Section, SiteSetting ].each { |model| model.update_all(updated_at: Time.utc(2001, 1, 1)) } unless @dated
      @dated = true
      { sections: Section.order(:id).map(&:attributes), settings: SiteSetting.order(:id).map(&:attributes) }
    end

    # The stored state with only the named content fields replaced:
    # { [ key, field ] => value }, a setting's field being "value".
    def expected_after(before, changes)
      before.transform_values do |rows|
        rows.map { |row| changes.reduce(row) { |acc, ((key, field), value)| acc["key"] == key && acc.key?(field) ? acc.merge(field => value) : acc } }
      end
    end

    def swap(direction)
      load Rails.root.join("db/migrate/20261022120000_swap_sdlc_copy.rb").to_s
      ActiveRecord::Migration.suppress_messages { SwapSdlcCopy.new.migrate(direction) }
    end
end
