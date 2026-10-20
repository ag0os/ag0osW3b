require "test_helper"
require "open3"
require "stringio"

class ClientAddressContractTest < ActionDispatch::IntegrationTest
  CLIENT = "181.47.0.1"
  FORGED = "203.0.113.9"
  LOOPBACK_PEERS = [ "127.0.0.1", "::1" ].freeze

  setup do
    @log = StringIO.new
    @logger = ActiveSupport::Logger.new(@log, level: Logger::INFO)
    @previous_level = Rails.logger.level
    Rails.logger.level = Logger::INFO
    Rails.logger.broadcast_to(@logger)
  end

  teardown do
    Rails.logger.stop_broadcasting_to(@logger)
    Rails.logger.level = @previous_level
  end

  LOOPBACK_PEERS.each do |peer|
    test "CA-1 conflicting Client-IP through #{peer} answers normally and records the proxy address" do
      assert_recorded_address peer, CLIENT, "HTTP_CLIENT_IP" => FORGED
    end

    test "CA-1 Forwarded through #{peer} cannot replace the proxy address" do
      assert_recorded_address peer, CLIENT, "HTTP_FORWARDED" => "for=#{FORGED}"
    end

    test "CA-1 both competing headers through #{peer} answer normally and record the proxy address" do
      assert_recorded_address peer, CLIENT,
        "HTTP_CLIENT_IP" => FORGED, "HTTP_FORWARDED" => "for=#{FORGED}"
    end

    test "CA-1 an ordinary request through #{peer} keeps the proxy address" do
      assert_recorded_address peer, CLIENT
    end
  end

  [ "80.58.0.1", "2001:4860::1" ].each do |peer|
    test "CA-1 direct public peer #{peer} cannot forge X-Forwarded-For" do
      assert_recorded_address peer, peer
    end

    test "CA-1 direct public peer #{peer} cannot use competing headers" do
      assert_recorded_address peer, peer,
        "HTTP_CLIENT_IP" => FORGED, "HTTP_FORWARDED" => "for=#{FORGED}"
    end
  end

  test "CA-1 wiring precedes RemoteIp and the request logger in the real application stack" do
    stack = Rails.application.middleware.map(&:klass)
    boundary = stack.index { |klass| klass.name == "ClientAddress" }
    assert_not_nil boundary, stack.map(&:name).join(" -> ")
    assert_operator boundary, :<, stack.index(ActionDispatch::RemoteIp)
    assert_operator stack.index(ActionDispatch::RemoteIp), :<, stack.index(Rails::Rack::Logger)
  end

  test "CA-1 wiring boots and eager loads without making the middleware reloadable" do
    output, status = Open3.capture2e(
      { "RAILS_ENV" => "development" }, "bin/rails", "runner", <<~'RUBY', chdir: Rails.root.to_s
        Rails.application.eager_load!
        original = ClientAddress
        Rails.application.reloader.reload!
        Rails.application.eager_load!
        abort "middleware was reloaded" unless ClientAddress.equal?(original)
        abort "stack has a stale middleware" unless Rails.application.middleware.any? { |entry| entry.klass.equal?(original) }
        puts "CLIENT_ADDRESS_BOOT_OK"
      RUBY
    )
    assert status.success?, output
    assert_includes output, "CLIENT_ADDRESS_BOOT_OK"
  end

  private
    def assert_recorded_address(peer, expected, competing = {})
      headers = { "REMOTE_ADDR" => peer, "HTTP_X_FORWARDED_FOR" => CLIENT }.merge(competing)

      get "/about", headers: headers

      assert_response :ok
      assert_equal expected, request.remote_ip
      assert_includes @log.string, "Started GET \"/about\" for #{expected} at "

      assert_difference "Session.count", 1 do
        post session_path, params: { email_address: users(:one).email_address, password: "password" }, headers: headers
      end

      assert_response :redirect
      assert_equal expected, Session.order(:id).last.ip_address
      assert_includes @log.string, "Started POST \"/session\" for #{expected} at "
    end
end
