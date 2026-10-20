require "test_helper"

class LocaleVaryContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#locale_cache_headers" if respond_to?(:cover)

  test "LC-19 an absent Vary becomes only the language field" do
    without_vary = -> { response.headers.delete("Vary") }
    SiteController.before_action(without_vary)
    begin
      get "/about"
      assert_response :success
      assert_equal [ "Accept-Language" ], response.headers.fetch("Vary").split(",").map(&:strip)
    ensure
      SiteController.skip_before_action(without_vary)
    end
  end

  test "LC-19 bare Vary preserves existing fields while a fixed address adds none" do
    existing_vary = -> { response.headers["Vary"] = "Accept-Encoding" }
    SiteController.before_action(existing_vary)
    begin
      { "/about" => "Accept-Encoding, Accept-Language", "/es/about" => "Accept-Encoding" }.each do |path, vary|
        get path
        assert_response :success
        assert_equal vary, response.headers["Vary"]
      end
    ensure
      SiteController.skip_before_action(existing_vary)
    end
  end
end
