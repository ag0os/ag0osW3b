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
end
