require "test_helper"

module Madmin
  class AdminLocaleTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
    end

    test "uses admin stored locale preference" do
      @admin.update_column(:locale, "es")
      sign_in_admin @admin

      get madmin_root_path
      assert_response :success
      assert_equal :es, I18n.locale
    end

    test "falls back to Accept-Language header when admin has no locale" do
      @admin.update_column(:locale, nil)
      sign_in_admin @admin

      get madmin_root_path, headers: { "Accept-Language" => "fr;q=0.9, en;q=0.5" }
      assert_response :success
      assert_equal :fr, I18n.locale
    end

    test "falls back to Setting.default_language when no preference and no Accept-Language match" do
      @admin.update_column(:locale, nil)
      Setting.instance.update!(default_language: "es")
      sign_in_admin @admin

      get madmin_root_path, headers: { "Accept-Language" => "zh;q=0.9" }
      assert_response :success
      assert_equal :es, I18n.locale
    ensure
      Setting.instance.update!(default_language: "en")
    end

    test "falls back to en when default_language is blank and no other match" do
      @admin.update_column(:locale, nil)
      Setting.instance.update!(default_language: nil)
      sign_in_admin @admin

      get madmin_root_path, headers: { "Accept-Language" => "zh;q=0.9" }
      assert_response :success
      assert_equal :en, I18n.locale
    ensure
      Setting.instance.update!(default_language: "en")
    end

    test "admin locale auto-detected from browser on first sign-in" do
      @admin.update_column(:locale, nil)

      post admins_session_path, params: { session: { email: @admin.email } }
      token = @admin.generate_magic_link_token

      get admins_verify_magic_link_path(token: token), headers: { "Accept-Language" => "fr;q=0.9, en;q=0.5" }
      assert_redirected_to "/madmin"

      @admin.reload
      assert_equal :fr, @admin.locale.to_sym
    end

    test "admin locale not overwritten on subsequent sign-ins" do
      @admin.update_column(:locale, "es")

      post admins_session_path, params: { session: { email: @admin.email } }
      token = @admin.generate_magic_link_token

      get admins_verify_magic_link_path(token: token), headers: { "Accept-Language" => "fr;q=0.9" }
      assert_redirected_to "/madmin"

      @admin.reload
      assert_equal "es", @admin.locale
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { session: { email: admin.email } }
      token = admin.generate_magic_link_token
      get admins_verify_magic_link_path(token: token)
    end
  end
end
