require "test_helper"

class LocaleVaryContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#locale_cache_headers" if respond_to?(:cover)

  test "LC-19 an absent Vary gains the language field once and keeps the rest" do
    without_vary = -> { response.headers.delete("Vary") }
    SiteController.before_action(without_vary)
    begin
      before, after = vary_around_locale_headers("/about")
      assert_not_includes before, "Accept-Language"
      assert_language_added_once before, after
    ensure
      SiteController.skip_before_action(without_vary)
    end
  end

  test "LC-19 bare Vary preserves existing fields while a fixed address adds none" do
    existing_vary = -> { response.headers["Vary"] = "Accept-Encoding" }
    SiteController.before_action(existing_vary)
    begin
      before, after = vary_around_locale_headers("/about")
      assert_includes before, "Accept-Encoding"
      assert_language_added_once before, after

      %w[ /es/about /en/about ].each do |path|
        before, after = vary_around_locale_headers(path)
        assert_includes before, "Accept-Encoding", path
        assert_not_includes after, "Accept-Language", path
        assert_equal before, after, path
      end
    ensure
      SiteController.skip_before_action(existing_vary)
    end
  end

  private
    # After callbacks run last-declared first, so this one reads Vary just
    # before SiteController#locale_cache_headers changes it.
    def vary_around_locale_headers(path)
      before = nil
      recorder = -> { before = response.headers["Vary"] }
      SiteController.after_action(recorder)
      get path
      assert_response :success
      [ vary_fields(before), vary_fields(response.headers["Vary"]) ]
    ensure
      SiteController.skip_after_action(recorder)
    end

    def vary_fields(value)
      value.to_s.split(",").map(&:strip).reject(&:empty?)
    end

    def assert_language_added_once(before, after)
      assert_equal 1, after.count("Accept-Language"), after.inspect
      assert_equal before, after - [ "Accept-Language" ]
    end
end
