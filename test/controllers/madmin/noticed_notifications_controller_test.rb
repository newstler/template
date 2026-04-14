require "test_helper"

module Madmin
  class NoticedNotificationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      sign_in_admin @admin
    end

    test "admin can list noticed notifications" do
      get madmin_noticed_notifications_path
      assert_response :success
    end

    test "admin can view a noticed notification" do
      user = users(:one)
      WelcomeNotifier.with(record: user).deliver(user)
      notification = Noticed::Notification.last

      get madmin_noticed_notification_path(notification)
      assert_response :success
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { session: { email: admin.email } }
      token = admin.generate_magic_link_token
      get admins_verify_magic_link_path(token: token)
    end
  end
end
