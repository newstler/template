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

    test "total revenue iterates all paid invoices via Stripe pagination" do
      Setting.instance.update!(stripe_secret_key: "sk_test_fake")
      Rails.cache.delete("admin:total_revenue")
      Rails.cache.delete("admin_subscription_revenue")

      fake_invoices = [
        Struct.new(:amount_paid).new(1_000),
        Struct.new(:amount_paid).new(2_500),
        Struct.new(:amount_paid).new(500)
      ]
      fake_page = Object.new
      fake_page.define_singleton_method(:auto_paging_each) do |&block|
        fake_invoices.each(&block)
      end

      original_invoice_list = Stripe::Invoice.method(:list)
      original_subscription_list = Stripe::Subscription.method(:list)
      Stripe::Invoice.define_singleton_method(:list) { |**_| fake_page }
      Stripe::Subscription.define_singleton_method(:list) { |**_| Struct.new(:data).new([]) }

      begin
        get madmin_root_path
        assert_response :success
        assert_match "40.00", response.body # 1000 + 2500 + 500 = 4000 cents = $40
      ensure
        Stripe::Invoice.define_singleton_method(:list, original_invoice_list)
        Stripe::Subscription.define_singleton_method(:list, original_subscription_list)
        Setting.instance.update!(stripe_secret_key: nil)
        Rails.cache.delete("admin:total_revenue")
        Rails.cache.delete("admin_subscription_revenue")
      end
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { session: { email: admin.email } }
      token = admin.generate_magic_link_token
      get admins_verify_magic_link_path(token: token)
    end
  end
end
