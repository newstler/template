require "test_helper"

module Madmin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      sign_in_admin @admin
    end

    test "admin dashboard renders at madmin root" do
      get madmin_root_path
      assert_response :success
    end

    test "dashboard exposes total KPI aggregates" do
      get madmin_root_path
      assert_response :success
      assert_match I18n.t("madmin.dashboard.show.kpi.total_users"), response.body
      assert_match I18n.t("madmin.dashboard.show.kpi.total_teams"), response.body
      assert_match I18n.t("madmin.dashboard.show.kpi.total_cost"), response.body
    end

    test "dashboard renders time range selector with 30d default" do
      get madmin_root_path
      assert_select "option[selected][value='30d']"
    end

    test "dashboard respects ?range= param" do
      get madmin_root_path, params: { range: "7d" }
      assert_select "option[selected][value='7d']"
    end

    test "dashboard shows subscription stats section" do
      get madmin_root_path
      assert_match I18n.t("madmin.dashboard.show.subscriptions.heading"), response.body
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { session: { email: admin.email } }
      token = admin.generate_magic_link_token
      get admins_verify_magic_link_path(token: token)
    end
  end
end
