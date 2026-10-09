require "test_helper"

# The Contract for retiring the command line's settings, as tests. Each test is
# named after an obligation in PRODUCT.md ("Contract: retiring the shell's
# settings"). This is the one test file that names the three keys: it exists to
# prove they are gone.
class RemoveShellSettingsContractTest < ActionDispatch::IntegrationTest
  RETIRED = %w[ shell_opening shell_whoami shell_whoami_es ].freeze

  setup do
    SiteSetting.create!(RETIRED.map { |key| { key: key, value: "stored #{key}" } })
    SiteSetting["tagline"] = "A stored tagline."
    SiteSetting["hero_note_es"] = "Una nota guardada."
  end

  test "DM-1 the migration deletes the three rows and no other" do
    others = SiteSetting.where.not(key: RETIRED).pluck(:key, :value).sort

    migrate :up

    assert_empty SiteSetting.where(key: RETIRED)
    assert_equal others, SiteSetting.pluck(:key, :value).sort
  end

  test "DM-2 it runs cleanly on a database that never had them, or runs twice" do
    SiteSetting.where(key: RETIRED).delete_all
    others = SiteSetting.pluck(:key, :value).sort

    migrate :up
    migrate :up

    assert_equal others, SiteSetting.pluck(:key, :value).sort
  end

  test "DM-2 rolling it back raises nothing and restores nothing" do
    migrate :up
    rows = SiteSetting.pluck(:key, :value).sort

    migrate :down

    assert_equal rows, SiteSetting.pluck(:key, :value).sort
  end

  test "DM-3 it works on the table in SQL and never loads the model" do
    assert_no_match(/\bSiteSetting\b/, migration_file.read)
  end

  test "DM-4 afterwards the admin's settings page offers no field for them" do
    migrate :up
    sign_in_as users(:one)

    get admin_site_settings_path

    assert_response :success
    RETIRED.each do |key|
      assert_select "[name=?]", "settings[#{key}]", { count: 0 }, key
      assert_nil SiteSetting[key], key
    end
    assert_select "[name=?]", "settings[tagline]", 1
  end

  private
    def migration_file
      files = Pathname.glob(Rails.root.join("db/migrate/*_remove_shell_settings.rb"))
      assert_equal 1, files.size, "one migration named *_remove_shell_settings.rb in db/migrate"
      files.first
    end

    def migrate(direction)
      load migration_file.to_s
      ActiveRecord::Migration.suppress_messages { RemoveShellSettings.new.migrate(direction) }
    end
end
