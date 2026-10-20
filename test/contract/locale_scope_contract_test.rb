require "test_helper"

class LocaleScopeContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#switch_locale" if respond_to?(:cover)

  test "LC-18 language addresses render their path language" do
    %w[es en].each do |locale|
      get "/#{locale}/about"
      assert_response :success
      assert_select "html[lang=?]", locale
    end
  end
end
