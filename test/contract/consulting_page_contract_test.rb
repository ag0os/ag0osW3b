require "test_helper"

class ConsultingPageContractTest < ActionDispatch::IntegrationTest
  cover "PagesController#consulting" if respond_to?(:cover)

  HEADING = "Agustín Calabrese: agentic development and AI-native systems"
  SPANISH_HEADING = "Agustín Calabrese: desarrollo con agentes y sistemas AI-native"
  APPROVED = <<~TEXT
    Agustín Calabrese: agentic development and AI-native systems

    I'm a software engineer. Since 2025 I build the systems that let agents write good software, and I help teams do the same. In 2024 I stopped writing code by hand.

    1. Agentic development for software teams

    Your developers already have Claude Code, Codex or Cursor. Getting real work
    out of them is a different thing. I help teams set up how they work with
    agents:

    Plans before code, and context the next agent can pick up.
    Review by a different model, so one agent checks another.
    Coordination when many agents work at once, across several projects.
    The engineering basics built into the system: tests that mean something,
      a codebase the next person can read, tech debt caught early.

    This is how I work every day, with Shepherd: one agent per project that
    keeps the context, tracks the work and runs the other agents. It is part of
    Troupe, which is public: github.com/ag0os/troupe.

    2. Building AI-native systems

    You know your domain. I know how to turn that knowledge into a system that
    works: agents, tools and the checks that make the output trustworthy. I can
    help you design it and build it.

    Background

    16+ years in IT, 6+ in software engineering, across payments, video
    streaming and enterprise platforms. Ruby on Rails, TypeScript. Claude
    Certified Architect (Foundations).
  TEXT

  setup do
    # Exercise the real seed copy, not a second fixture that could drift from it.
    capture_io { load Rails.root.join("db/seeds.rb") }
  end

  test "CP-1 approved copy and structure are public and unchanged" do
    get "/consulting"
    assert_response :success
    assert_select "main h1", count: 1, text: HEADING
    assert_equal [ "1. Agentic development for software teams", "2. Building AI-native systems", "Background" ], css_select("main h2").map(&:text)
    assert_select "main ul li", 4
    text = css_select("main").first.text.tr("’", "'").squish
    assert_equal (APPROVED + " Want to talk about your team? Get in touch on LinkedIn.").squish, text
    assert_no_match(/[—–]/, text)
  end

  test "CP-2 only visible consulting sections appear in position then id order" do
    Section.create!(page: "consulting", key: "consulting_last", heading: "Last", body: "Last body", position: 9)
    Section.create!(page: "consulting", key: "consulting_first", heading: "First", body: "First body", position: 0)
    Section.create!(page: "consulting", key: "consulting_tie", heading: "Tie", body: "Tie body", position: 0)
    Section.create!(page: "consulting", key: "consulting_hidden", body: "Hidden consulting body", visible: false)
    # The page/position index can accidentally supply the right order even
    # without ORDER BY. Reverse unordered scans to verify the guarantee.
    Section.connection.execute("PRAGMA reverse_unordered_selects = ON")
    get "/consulting"
    assert_response :success
    assert_equal %w[consulting_first consulting_tie consulting_intro consulting_agentic consulting_systems consulting_background consulting_last], css_select("main section").map { |s| s["id"] }
    assert_no_match(/Hidden consulting body|Hello from|Selected proof/, css_select("main").to_s)
    assert_select "main #consulting_first .prose p", text: "First body"
  ensure
    Section.connection.execute("PRAGMA reverse_unordered_selects = OFF")
  end

  test "CP-3 repository and contact links use the specified destinations" do
    SiteSetting["linkedin_url"] = "https://www.linkedin.com/in/current-profile"
    get "/consulting"
    assert_select 'main a[href="https://github.com/ag0os/troupe"]', text: "github.com/ag0os/troupe"
    assert_select 'main a[href="https://www.linkedin.com/in/current-profile"][target="_blank"][rel="noopener"]', count: 1, text: "LinkedIn"
    assert_select "main > .page > p", text: "Want to talk about your team? Get in touch on LinkedIn."
  end

  test "CP-4 title and descriptions are escaped plain text" do
    SiteSetting["site_title"] = 'Test <site> & "title"'
    Section.find_by!(key: "consulting_intro").update!(body: %(An ==intro== with <tag> & "quotes".\nNext line.))
    get "/consulting"
    title = "#{HEADING} · #{SiteSetting["site_title"]}"
    description = 'An intro with <tag> & "quotes". Next line.'
    assert_select "title", text: title
    assert_select 'meta[property="og:title"]' do |nodes|
      assert_equal title, nodes.first["content"]
    end
    [ 'meta[name="description"]', 'meta[property="og:description"]' ].each do |selector|
      assert_equal description, css_select(selector).first["content"]
    end
    assert_select "head site, head tag", 0
    assert_includes response.body, "&lt;site&gt;"
    assert_includes response.body, "&lt;tag&gt;"
  end

  test "CP-4 the seeded intro describes the page and hidden intro uses the layout fallback" do
    intro = Section.find_by!(key: "consulting_intro")
    get "/consulting"
    [ 'meta[name="description"]', 'meta[property="og:description"]' ].each do |selector|
      assert_equal intro.body.squish, css_select(selector).first["content"]
    end
    intro.update!(visible: false)
    SiteSetting["tagline"] = "Fallback ==description==."
    get "/consulting"
    assert_equal "Fallback description.", css_select('meta[name="description"]').first["content"]
  end

  test "CP-5 English copy under English, with English chrome and no consulting nav link" do
    get "/consulting"
    assert_select "html[lang=en]"
    assert_select "main [lang]", 0
    assert_select "nav a", text: "Home"
    assert_select '.language-controls[aria-label="Language"]'
    assert_select '[data-controller="theme"]'
    assert_select '.site-header nav a[href="/consulting"]', 0
  end

  test "CP-5 Spanish copy under Spanish, with Spanish chrome and no consulting nav link" do
    SiteSetting["linkedin_url"] = "https://www.linkedin.com/in/current-profile"
    spanish = Section.for_page("consulting").ordered
    cookies[:locale] = "es"
    get "/consulting"
    assert_select "html[lang=es]"
    assert_select "main h1", count: 1, text: SPANISH_HEADING
    assert_equal spanish.filter_map(&:heading_es), css_select("main h2").map(&:text)
    assert_select "main [lang]", 0
    assert_select "main > .page > p", text: "¿Querés hablar de tu equipo? Escribime por LinkedIn."
    assert_select 'main a[href="https://www.linkedin.com/in/current-profile"][target="_blank"][rel="noopener"]', count: 1, text: "LinkedIn"
    assert_select "title", text: "#{SPANISH_HEADING} · #{SiteSetting["site_title"]}"
    assert_equal spanish.first.body_es.squish, css_select('meta[name="description"]').first["content"]
    assert_select "nav a", text: "Inicio"
    assert_select '.language-controls[aria-label="Idioma"]'
    assert_select '[data-controller="theme"]'
    assert_select '.site-header nav a[href="/consulting"]', 0
  end
end
