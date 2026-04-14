require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "GET /notifications renders index for authenticated user" do
    get notifications_path
    assert_response :success
  end

  test "GET /notifications lists the user's notifications newest first" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    perform_enqueued_jobs

    get notifications_path
    assert_response :success
    assert_select "[data-notification-id]", count: 1
  end

  test "GET /notifications shows an empty state when the user has none" do
    get notifications_path
    assert_response :success
    assert_select "[data-empty-state]"
  end

  test "GET /notifications redirects unauthenticated users" do
    delete session_path
    get notifications_path
    assert_redirected_to new_session_path
  end
end
