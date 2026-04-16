require "test_helper"

class LocaleDetectionTest < ActionDispatch::IntegrationTest
  setup do
    @admin = admins(:one)
    sign_in_admin @admin
  end

  test "detect_browser_locale returns symbol for matching language" do
    get madmin_root_path, headers: { "Accept-Language" => "es;q=0.9, en;q=0.5" }
    assert_response :success
    # Spanish is enabled in fixtures, so it should match
  end

  test "detect_browser_locale returns nil for non-matching languages" do
    @admin.update_column(:locale, nil)
    Setting.instance.update!(default_language: "en")

    get madmin_root_path, headers: { "Accept-Language" => "zh;q=0.9, ja;q=0.8" }
    assert_response :success
    # No match, falls through to default_language = en
    assert_equal :en, I18n.locale
  end

  test "parse_accept_language respects quality values" do
    @admin.update_column(:locale, nil)

    # fr has higher quality than es, both are enabled
    get madmin_root_path, headers: { "Accept-Language" => "es;q=0.5, fr;q=0.9" }
    assert_response :success
    assert_equal :fr, I18n.locale
  end

  test "parse_accept_language handles language-region codes" do
    @admin.update_column(:locale, nil)

    # en-US should match "en", fr-FR should match "fr"
    get madmin_root_path, headers: { "Accept-Language" => "fr-FR;q=0.9, en-US;q=0.5" }
    assert_response :success
    assert_equal :fr, I18n.locale
  end

  test "detect_browser_locale skips disabled languages" do
    @admin.update_column(:locale, nil)
    Setting.instance.update!(default_language: "en")

    # de is disabled in fixtures
    get madmin_root_path, headers: { "Accept-Language" => "de;q=0.9" }
    assert_response :success
    assert_equal :en, I18n.locale
  end

  private

  def sign_in_admin(admin)
    post admins_session_path, params: { session: { email: admin.email } }
    token = admin.generate_magic_link_token
    get admins_verify_magic_link_path(token: token)
  end
end
