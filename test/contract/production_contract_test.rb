require "test_helper"
require "open3"

# The production deploy's Contract, as tests. Each test is named after an
# obligation in PRODUCT.md ("Contract: the production deploy"). PD-1 to PD-3
# run the real seeds with Rails.env switched; PD-4 boots production.
class ProductionContractTest < ActiveSupport::TestCase
  ADMIN_EMAIL = "agoos@hey.com"
  SEEDED = [ User, Section, SiteSetting, Post ].freeze

  setup do
    @env = ENV.to_h.slice("ADMIN_EMAIL", "ADMIN_PASSWORD")
    ENV.delete("ADMIN_EMAIL")
    ENV.delete("ADMIN_PASSWORD")
  end

  teardown do
    Rails.env = "test"
    ENV.delete("ADMIN_PASSWORD")
    ENV.update(@env)
  end

  test "PD-1 in production, seeding without ADMIN_PASSWORD raises, naming it, before writing anything" do
    Rails.env = "production"

    [ nil, "", "   " ].each do |password|
      ENV["ADMIN_PASSWORD"] = password
      before = snapshot

      error = assert_raises(RuntimeError) { seed }

      assert_match(/ADMIN_PASSWORD/, error.message, password.inspect)
      assert_equal before, snapshot, "wrote with ADMIN_PASSWORD=#{password.inspect}"
    end
  end

  test "PD-1 in production, it raises even when the admin already exists" do
    User.create!(email_address: ADMIN_EMAIL, password: "already-set")
    Rails.env = "production"
    before = snapshot

    assert_raises(RuntimeError) { seed }
    assert_equal before, snapshot
  end

  test "PD-2 in production, the admin gets ADMIN_PASSWORD and nothing printed contains it" do
    Rails.env = "production"
    ENV["ADMIN_PASSWORD"] = password = "from-the-env-#{SecureRandom.hex(8)}"

    output = seed

    assert User.find_by!(email_address: ADMIN_EMAIL).authenticate(password)
    assert_match(/Created admin user #{ADMIN_EMAIL}/, output)
    assert_not_includes output, password
  end

  test "PD-3 in development and test, the admin gets the default password, printed" do
    %w[development test].each do |env|
      User.where(email_address: ADMIN_EMAIL).delete_all
      Rails.env = env

      output = seed

      assert User.find_by!(email_address: ADMIN_EMAIL).authenticate("change-me-please"), env
      assert_includes output, "change-me-please", env
    end
  end

  test "PD-4 in production, mail links are built for https://agoos.dev" do
    output, status = Open3.capture2e(
      { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1" },
      "bin/rails", "runner", 'print "\nURL=", PasswordsMailer.new.edit_password_url("a-token")',
      chdir: Rails.root.to_s
    )

    assert status.success?, output
    assert_equal "https://agoos.dev/passwords/a-token/edit", output[/^URL=(.*)\z/, 1], output
  end

  private
    def seed
      out, err = capture_io { load Rails.root.join("db/seeds.rb") }
      out + err
    end

    def snapshot
      SEEDED.to_h { |model| [ model.name, model.order(:id).map(&:attributes) ] }
    end
end
