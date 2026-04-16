require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    # Clear fixture notifications so counts start from a clean slate
    @user.notifications.destroy_all
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

  test "layout shows unread count badge when user has unread notifications" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    perform_enqueued_jobs

    get notifications_path
    assert_response :success
    assert_select "a[href='#{notifications_path}'] .bg-red-500", text: "1"
  end

  test "layout hides badge when user has no unread notifications" do
    get notifications_path
    assert_response :success
    assert_select "a[href='#{notifications_path}'] .bg-red-500", count: 0
  end

  test "PATCH /notifications/:id/mark_read marks a notification as read" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    perform_enqueued_jobs

    notification = @user.notifications.reload.last
    assert_not_nil notification
    assert_nil notification.read_at

    patch mark_read_notification_path(notification), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success

    assert notification.reload.read_at.present?
  end
end
