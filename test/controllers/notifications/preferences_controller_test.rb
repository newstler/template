require "test_helper"

class Notifications::PreferencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "edit renders the preferences form" do
    get edit_notification_preferences_path
    assert_response :success
    assert_match I18n.t("notifications.preferences.edit.title"), response.body
  end

  test "update stores sanitized preferences" do
    patch notification_preferences_path, params: {
      notification_preferences: {
        welcome_notifier: { email: "0", database: "1" }
      }
    }
    assert_response :redirect
    @user.reload
    assert_equal({ "email" => false, "database" => true },
                 @user.notification_preferences["welcome_notifier"])
  end

  test "update ignores unknown kinds" do
    patch notification_preferences_path, params: {
      notification_preferences: {
        fake_notifier: { email: "1" }
      }
    }
    @user.reload
    assert_nil @user.notification_preferences["fake_notifier"]
  end
end
