require "application_system_test_case"

class NotificationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "inbox shows a notification the user has received" do
    @user.notifications.destroy_all
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    perform_enqueued_jobs

    sign_in_as @user
    visit notifications_path

    assert_selector "[data-notification-id]"
  end

  test "inbox empty state when user has no notifications" do
    @user.notifications.destroy_all
    sign_in_as @user
    visit notifications_path

    assert_selector "[data-empty-state]"
  end
end
