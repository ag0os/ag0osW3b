require "test_helper"

class LocaleNavigationContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#default_url_options" if respond_to?(:cover)

  test "LC-21 public navigation lists and Copy links retain language without scoped control URLs" do
    %w[en es].each do |locale|
      get "/#{locale}"
      assert_select ".site-header a[href=?]", "/#{locale}"
      %w[about work contact writing].each { |page| assert_select ".site-header nav a[href=?]", "/#{locale}/#{page}" }
      assert_select ".post-list a[href=?]", "/#{locale}/writing/published-post"
      assert_select ".site-footer__cta a[href=?]", "/#{locale}/consulting"
      assert_select 'form[action="/locale"]', count: 2
      assert_select 'a[href*="?locale="], form[action*="?locale="]', count: 0
    end
  end

  test "LC-21 negotiated bare pages generate language paths and a bare control URL" do
    %w[en es].each do |locale|
      cookies[:locale] = locale
      get "/"
      assert_response :success
      assert_select "html[lang=?]", locale
      assert_select ".site-header a[href=?]", "/#{locale}"
      %w[about work contact writing].each { |page| assert_select ".site-header nav a[href=?]", "/#{locale}/#{page}" }
      assert_select ".post-list a[href=?]", "/#{locale}/writing/published-post"
      assert_select ".site-footer__cta a[href=?]", "/#{locale}/consulting"
      assert_select 'form[action="/locale"]', count: 2
      assert_select 'a[href*="?locale="], form[action*="?locale="]', count: 0
    end
  end
end
