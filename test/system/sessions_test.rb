require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "user signs in via magic link flow" do
    visit new_session_path

    fill_in "session[email]", with: @user.email
    find("form[action='#{session_path}'] input[type='submit']").click

    assert_text I18n.t("controllers.sessions.create.notice"), wait: 5

    visit verify_magic_link_path(token: @user.generate_magic_link_token)

    assert_current_path(/\/(home|t\/|teams)/)
  end
end
