require "test_helper"

class CurrencyDetectionTest < ActionDispatch::IntegrationTest
  # Current.currency is reset between requests by ActiveSupport::CurrentAttributes.
  # We assert detection logic via the private method directly on an instance of
  # ApplicationController (simpler than exposing a test-only header).

  class FakeRequest
    attr_reader :remote_ip, :headers
    def initialize(remote_ip: "127.0.0.1")
      @remote_ip = remote_ip
      @headers = {}
    end
  end

  class FakeCookies
    def initialize(signed: {})
      @signed = signed
    end

    def signed = @signed
    def [](*) = nil
  end

  def build_controller(user: nil, team: nil, cookies: {})
    controller = ApplicationController.new
    controller.instance_variable_set(:@current_user, user)
    Current.user = user
    Current.team = team
    controller.define_singleton_method(:current_user) { user }
    controller.define_singleton_method(:current_team) { team }
    controller.define_singleton_method(:cookies) { FakeCookies.new(signed: cookies) }
    controller.define_singleton_method(:request) { FakeRequest.new }
    controller
  end

  teardown do
    Current.reset
  end

  test "returns user preferred_currency when present" do
    user = users(:one)
    user.preferred_currency = "EUR"
    controller = build_controller(user: user)
    assert_equal "EUR", controller.send(:detect_currency)
  end

  test "returns signed cookie value when it is a supported currency" do
    controller = build_controller(cookies: { tmpl_currency: "GBP" })
    assert_equal "GBP", controller.send(:detect_currency)
  end

  test "ignores signed cookie value when it is unsupported" do
    controller = build_controller(cookies: { tmpl_currency: "XXX" })
    # Falls through to Setting.default_currency (USD)
    assert_equal Setting.default_currency, controller.send(:detect_currency)
  end

  test "falls back to team default when no user or cookie" do
    team = teams(:one)
    team.default_currency = "CHF"
    controller = build_controller(team: team)
    assert_equal "CHF", controller.send(:detect_currency)
  end

  test "falls back to Setting.default_currency when nothing else matches" do
    controller = build_controller
    assert_equal Setting.default_currency, controller.send(:detect_currency)
  end
end
