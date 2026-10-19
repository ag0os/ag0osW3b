require "test_helper"

# Writing's Contract, as tests: where the writing shows before there is any.
# Each test is named after an obligation in docs/contracts/writing.md.
class WritingContractTest < ActionDispatch::IntegrationTest
  PAGES = %w[/ /about /work /contact /consulting /writing].freeze
  LABELS = { "en" => "Writing", "es" => "Escritos" }.freeze

  test "WR-1 with a post published, the primary nav links to Writing in both languages" do
    LABELS.each do |locale, label|
      cookies[:locale] = locale
      PAGES.each do |path|
        get path
        assert_select ".site-header nav a[href=?]", posts_path, { count: 1, text: label }, "#{path} in #{locale}"
      end
    end
  end

  test "WR-1 with only drafts, the primary nav has no Writing link in either language" do
    Post.published.delete_all
    assert Post.draft.exists?

    LABELS.each do |locale, label|
      cookies[:locale] = locale
      PAGES.each do |path|
        get path
        assert_select ".site-header nav a[href=?]", posts_path, { count: 0 }, "#{path} in #{locale}"
        assert_select ".site-header nav a", { text: label, count: 0 }, "#{path} in #{locale}"
      end
    end
  end

  test "WR-1 with no posts at all, the primary nav has no Writing link" do
    Post.delete_all

    get root_path
    assert_select ".site-header nav a", 4
    assert_select ".site-header nav a[href=?]", posts_path, 0
  end

  test "WR-1 the first published post brings the link back, with no setting to change" do
    Post.published.delete_all
    get root_path
    assert_select ".site-header nav a[href=?]", posts_path, 0

    posts(:draft_post).published!

    get root_path
    assert_select ".site-header nav a[href=?]", posts_path, 1
  end

  test "WR-2 /writing answers 200 with the empty state when nothing is published" do
    Post.published.delete_all

    get posts_path

    assert_response :success
    assert_select "main h1", "Writing"
    assert_select "main p", text: "First essays coming soon."
    assert_select "main .post-list", 0
  end

  test "WR-3 /feed answers 200 with a valid, empty Atom feed when nothing is published" do
    Post.published.delete_all

    get feed_path

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    feed = Nokogiri::XML(response.body) { |config| config.strict }
    atom = { "atom" => "http://www.w3.org/2005/Atom" }
    assert_equal "feed", feed.root.name
    assert_equal atom["atom"], feed.root.namespace.href
    assert_predicate feed.at_xpath("/atom:feed/atom:id", atom)&.text, :present?
    assert_predicate feed.at_xpath("/atom:feed/atom:title", atom)&.text, :present?
    assert Time.iso8601(feed.at_xpath("/atom:feed/atom:updated", atom).text)
    assert_empty feed.xpath("//atom:entry", atom)
  end

  test "WR-4 the head links to the feed when nothing is published" do
    Post.delete_all

    PAGES.each do |path|
      get path
      assert_select "head link[rel=alternate][type=?][href=?]", "application/atom+xml", feed_url, { count: 1 }, path
    end
  end

  test "WR-5 /feed.xml answers 200 with the same Atom feed as /feed" do
    freeze_time

    get "/feed"
    feed = response.body

    get "/feed.xml"

    assert_response :success
    assert_equal "application/atom+xml", response.media_type
    assert_equal feed, response.body
  end

  test "WR-5 the feed in any other format answers 404, not an error" do
    %w[/feed.json /feed.rss /feed.html /feed.txt].each do |path|
      get path

      assert_response :not_found, path
    end
  end
end
