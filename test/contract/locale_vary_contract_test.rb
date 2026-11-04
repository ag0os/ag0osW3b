require "test_helper"

class LocaleVaryContractTest < ActionDispatch::IntegrationTest
  cover "SiteController#locale_cache_headers" if respond_to?(:cover)

  test "LC-19 an absent Vary becomes only the language field" do
    before, after = vary_around_locale_headers("/about", absent: true)
    assert_empty before
    assert_equal [ "Accept-Language" ], after
  end

  test "LC-19 bare Vary preserves existing fields while a fixed address adds none" do
    existing_vary = -> { response.headers["Vary"] = "Accept-Encoding" }
    SiteController.before_action(existing_vary)
    begin
      before, after = vary_around_locale_headers("/about")
      assert_includes before, "Accept-Encoding"
      assert_equal 1, after.count("Accept-Language"), after.inspect
      assert_equal before, after - [ "Accept-Language" ]

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
    # before SiteController#locale_cache_headers changes it. With absent:
    # it removes Vary there, after any fields the framework adds on render.
    def vary_around_locale_headers(path, absent: false)
      before = nil
      recorder = lambda do
        response.headers.delete("Vary") if absent
        before = response.headers["Vary"]
      end
      SiteController.after_action(recorder)
      get path
      assert_response :success
      after = vary_fields(response.headers["Vary"])
      assert_not_includes after, "", "Vary #{response.headers["Vary"].inspect} on #{path} has an empty field"
      [ vary_fields(before), after ]
    ensure
      SiteController.skip_after_action(recorder)
    end

    # Keeps empty fields, so a leading, trailing or doubled comma shows up.
    def vary_fields(value)
      value.to_s.split(",", -1).map(&:strip)
    end
end
