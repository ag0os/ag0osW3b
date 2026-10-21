require "test_helper"

class SessionContractTest < ActionDispatch::IntegrationTest
  MALFORMED = [
    {},
    { email_address: "one@example.com" },
    { password: "password" },
    { email_address: { address: "one@example.com" }, password: "password" },
    { email_address: "one@example.com", password: [ "password" ] }
  ].freeze

  NON_STRINGS = [ 42, true, false ].freeze

  teardown do
    Rails.cache.singleton_class.remove_method(:increment) if Rails.cache.singleton_methods.include?(:increment)
  end

  test "SE-1 a sign-in request without both credentials is refused with 400 and starts no session" do
    MALFORMED.each do |params|
      assert_no_difference -> { Session.count } do
        post session_path, params: params
      end
      assert_response :bad_request, "for #{params.inspect}"
      assert_nil cookies[:session_id]
    end
  end

  test "SE-1 a JSON number or boolean in either credential is refused with 400 and starts no session" do
    NON_STRINGS.each do |value|
      [ { email_address: value, password: "password" }, { email_address: "one@example.com", password: value } ].each do |params|
        assert_no_difference -> { Session.count } do
          post session_path, params: params, as: :json
        end
        assert_response :bad_request, "for #{params.inspect}"
        assert_nil cookies[:session_id]
      end
    end
  end

  test "SE-1 holds for requests the rate limiter admits; a throttled request keeps the limiter's redirect" do
    limiter = ActiveSupport::Cache::MemoryStore.new
    Rails.cache.define_singleton_method(:increment) { |*args, **options| limiter.increment(*args, **options) }
    10.times do
      post session_path, params: {}
      assert_response :bad_request
    end
    assert_no_difference -> { Session.count } do
      post session_path, params: { email_address: "one@example.com", password: "password" }
    end
    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
    assert_nil cookies[:session_id]
  end

  test "SE-1 blank credentials still return to the form as wrong credentials" do
    assert_no_difference -> { Session.count } do
      post session_path, params: { email_address: "", password: "" }
    end
    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "SE-1 the right pair still signs in and a wrong pair still returns to the form" do
    post session_path, params: { email_address: "one@example.com", password: "wrong" }
    assert_redirected_to new_session_path
    assert_nil cookies[:session_id]
    post session_path, params: { email_address: "one@example.com", password: "password" }
    assert_redirected_to root_path
    assert cookies[:session_id]
  end
end
