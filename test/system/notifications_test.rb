require "application_system_test_case"

class NotificationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "a new notification appears live in the inbox via Turbo Stream" do
    sign_in_as @user
    visit notifications_path

    assert_selector "[data-empty-state]"

    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    perform_enqueued_jobs

    assert_selector "[data-notification-id]", wait: 5
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_on "Send magic link"
    token = user.generate_magic_link_token
    visit verify_magic_link_path(token: token)
  end
end
