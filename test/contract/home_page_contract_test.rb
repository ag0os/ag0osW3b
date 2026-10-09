require "test_helper"

# The home page's Contract, as tests: what the page is once the command line
# is gone and before the copy replaces it. Each test is named after an
# obligation in PRODUCT.md ("Contract: the home page") and asserts only on the
# rendered HTML.
class HomePageContractTest < ActionDispatch::IntegrationTest
  cover "HomeController*" if respond_to?(:cover)

  # --- What it shows ----------------------------------------------------------

  test "HP-1 the h1 is the tagline in the page's language, marks drawn" do
    SiteSetting["tagline"] = "Builds ==careful== software."
    SiteSetting["tagline_es"] = "Construye software ==cuidadoso==."

    get root_path
    assert_select "h1", 1
    assert_select "h1", text: "Builds careful software."
    assert_select "h1 mark", text: "careful"

    cookies[:locale] = "es"
    get root_path
    assert_select "h1", text: "Construye software cuidadoso."
    assert_select "h1 mark", text: "cuidadoso"
  end

  test "HP-1 the hero note sits in the hero's rail, in the page's language" do
    SiteSetting["hero_note"] = "A note in English."
    SiteSetting["hero_note_es"] = "Una nota en castellano."

    get root_path
    assert_select ".hero .rail.note", text: "A note in English."

    cookies[:locale] = "es"
    get root_path
    assert_select ".hero .rail.note", text: "Una nota en castellano."
  end

  test "HP-1 the document title is the site title" do
    get root_path

    assert_select "title", text: "Test Site"
  end

  test "HP-2 every visible home section, in position order, with its heading, note and Markdown body" do
    Section.create!(key: "home_first", page: "home", heading: "First section", body: "First.", visible: true, position: 0)

    get root_path

    assert_equal [ "First section", "Intro", "Selected proof" ], css_select("main h2.section__heading").map { |h| h.text.strip }.first(3)
    assert_select "section#home_intro" do
      assert_select ".note", text: "A note in the margin."
      assert_select ".prose mark", text: "home"
    end
    assert_select "section#home_proof .prose li", /Hundreds of organizations/
  end

  test "HP-2 hidden sections and other pages' sections are absent" do
    Section.create!(key: "about_only", page: "about", heading: "About only", body: "Not on home.", position: 0)

    get root_path

    assert_select "section#home_hidden", 0
    assert_no_match(/A hidden block/, response.body)
    assert_no_match(/Not on home/, response.body)
  end

  test "HP-3 the three most recently published posts, newest first, each linked and dated" do
    4.times do |i|
      Post.create!(title: "Post #{i}", slug: "post-#{i}", body: "x", status: :published, published_at: Time.utc(2026, 6, 1 + i))
    end

    get root_path

    titles = css_select("main .post-list .post-list__title").map { |a| a.text.strip }
    assert_equal [ "Post 3", "Post 2", "Post 1" ], titles
    assert_select "main .post-list a[href=?]", post_path("post-3")
    assert_select "main .post-list time[datetime=?]", Time.utc(2026, 6, 4).iso8601
    assert_select "main a[href=?]", posts_path
  end

  test "HP-3 drafts never appear" do
    get root_path

    assert_select "main .post-list a", text: "Published Post"
    assert_no_match(/Draft Post/, css_select("main").to_s)
  end

  test "HP-3 with nothing published there is no list and no heading for it" do
    Post.published.delete_all

    get root_path

    assert_select "main .post-list", 0
    assert_select "main h2", { text: I18n.t("home.writing"), count: 0 }
  end

  # --- What it no longer is ---------------------------------------------------

  test "HP-4 no form or field on the page but the footer's language control" do
    get root_path

    actions = css_select("form").map { |form| form["action"] }
    assert_empty actions - [ "/locale" ], "a form other than the language control"
    assert_select "main input, main textarea, main select", 0
  end

  test "HP-4 no typed opening and no script controller of its own" do
    get root_path

    controllers = css_select("[data-controller]").flat_map { |el| el["data-controller"].split }
    assert_equal [ "theme" ], controllers.uniq, "only the header's theme controls"
    assert_select "main kbd", 0
  end

  test "HP-5 query parameters change nothing on the page" do
    get root_path
    plain = css_select("main").to_s

    get root_path(line: "cat home")

    assert_response :success
    assert_equal plain, css_select("main").to_s
    assert_no_match(/cat home/, response.body)
  end
end
