require "test_helper"

class SiteFlowTest < ActionDispatch::IntegrationTest
  setup { @user = users(:one) }

  # ---- public -------------------------------------------------------------
  test "public pages render" do
    [ root_path, about_path, work_path, contact_path, posts_path ].each do |path|
      get path
      assert_response :success, "expected #{path} to render"
    end
  end

  test "writing index lists published posts but not drafts" do
    get posts_path
    assert_response :success
    assert_select "a", text: "Published Post"
    assert_select "a", text: "Draft Post", count: 0
  end

  test "a published post renders its markdown body" do
    get post_path(posts(:published_post))
    assert_response :success
    assert_select "h1", /Published Post/
    assert_match %r{<strong>markdown</strong>}, @response.body
  end

  # ---- auth ---------------------------------------------------------------
  test "admin area requires authentication" do
    get admin_root_path
    assert_redirected_to new_session_path
  end

  # ---- admin CRUD ---------------------------------------------------------
  test "admin can create, publish, and delete a post" do
    sign_in_as @user

    assert_difference "Post.count", 1 do
      post admin_posts_path, params: { post: { title: "New Essay", body: "Hello world", status: "draft" } }
    end
    essay = Post.find_by!(slug: "new-essay")
    assert essay.draft?, "new post should default to draft"
    assert_redirected_to admin_posts_path

    patch admin_post_path(essay), params: { post: { status: "published" } }
    assert essay.reload.published?
    assert essay.published_at.present?, "publishing should set published_at"

    assert_difference "Post.count", -1 do
      delete admin_post_path(essay)
    end
  end

  test "admin can toggle a section's visibility" do
    sign_in_as @user
    section = sections(:home_hidden)
    assert_not section.visible?

    patch toggle_admin_section_path(section)
    assert_redirected_to admin_sections_path
    assert section.reload.visible?, "toggling a hidden section should make it visible"
  end

  test "admin can update site settings" do
    sign_in_as @user
    patch admin_site_settings_path, params: { settings: { "site_title" => "Brand New" } }
    assert_equal "Brand New", SiteSetting["site_title"]
  end
end
