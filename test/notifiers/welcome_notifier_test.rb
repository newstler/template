require "test_helper"

class WelcomeNotifierTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "delivering creates a noticed_notification for the recipient" do
    assert_difference -> { @user.notifications.count }, 1 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
      perform_enqueued_jobs
    end
  end

  test "delivering sends an email when email preference is enabled (default)" do
    assert_emails 1 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
      perform_enqueued_jobs
    end
  end

  test "delivering skips email when user has disabled it" do
    @user.update!(notification_preferences: { "welcome_notifier" => { "email" => false } })
    assert_emails 0 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
      perform_enqueued_jobs
    end
  end

  test "notification message reads from i18n" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    notification = @user.notifications.last
    assert_includes notification.message, @user.name.presence || @user.email
  end
end
