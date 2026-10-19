require "test_helper"

class SeededCopyContractTest < ActionDispatch::IntegrationTest
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
    get "/about"
    assert_response :success
    assert_select '#about_bio a[href="/consulting"]', count: 1

    get css_select('#about_bio a[href="/consulting"]').first["href"]
    assert_response :success
    assert_select "main #consulting_intro"
  end
  { "en" => "consulting", "es" => "consultoría" }.each do |locale, label|
    [ "/", "/about", "/work", "/contact", "/consulting", "/writing", "/writing/published-post" ].each do |path|
      test "SC-5 #{path} footer links #{label} to consulting in #{locale}" do
        cookies[:locale] = locale
        get path
        assert_response :success
        assert_select '.site-footer__cta a[href="/consulting"]', count: 1, text: label
      end
    end

    test "SC-5 Contact intro and About bio link to consulting in #{locale}" do
      cookies[:locale] = locale
      { "/contact" => "contact_intro", "/about" => "about_bio" }.each do |path, section|
        get path
        assert_response :success
        assert_select "##{section} a[href=\"/consulting\"]", count: 1
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

  test "SC-8 the migration fills every blank Spanish field of the seeded sections" do
    spanish = Section.pluck(:key, :heading_es, :note_es, :body_es).sort
    Section.update_all(heading_es: nil, note_es: nil, body_es: nil)

    migrate :up

    assert_equal spanish, Section.pluck(:key, :heading_es, :note_es, :body_es).sort
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

    spanish = YAML.load_file(Rails.root.join("db/seeds/sections_es.yml"))
    expected = before.map { |row| row.merge(spanish.fetch(row["key"], {}).select { |field, _| row[field].blank? }) }
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

  test "settled taglines describe the home page and its link previews in both languages" do
    SiteSetting.where(key: %w[tagline tagline_es]).delete_all
    { "en" => "Senior Software Engineer. I build the systems that let agents build good software.",
      "es" => "Ingeniero de software senior. Construyo los sistemas que permiten a los agentes construir buen software." }.each do |locale, tagline|
      cookies[:locale] = locale
      get "/"
      assert_select "main h1", count: 1, text: tagline
      assert_select "main h1 mark", 0
      [ 'meta[name="description"]', 'meta[property="og:description"]' ].each do |selector|
        assert_equal tagline, css_select(selector).first["content"]
      end
    end
  end

  test "settled Featured copy features Shepherd and identifies Cosmonauts as its paused predecessor" do
    featured = Section.find_by!(key: "home_featured")
    assert_equal "Featured: Shepherd", featured.heading
    assert_equal "Built it because I needed it.", featured.note
    assert_equal <<~MD.strip, featured.body.strip
      **Shepherd** is what I run every day: one agent per project that keeps the context, tracks the work across sessions and runs the other agents, on Claude Code or Codex. I run a flock of them. It lives in Troupe, my agent toolkit.

      [Troupe on GitHub →](https://github.com/ag0os/troupe)

      Before Shepherd I built **Cosmonauts**, an agent orchestration framework with verification inside the pipeline. Development is paused; the code is public.

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
      I'm open to roles building agent systems and AI-native products, and to [consulting](/consulting) for teams adopting agents.
      The fastest way to reach me is email, or find me on LinkedIn and GitHub below.
    MD
    { "en" => "Open to roles building agent systems and AI-native products, and to consulting.",
      "es" => "Abierto a roles construyendo sistemas de agentes y productos AI-native, y a consultoría." }.each do |locale, invitation|
      cookies[:locale] = locale
      get "/contact"
      assert_select '#contact_intro a[href="/consulting"]', count: 1
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
end
