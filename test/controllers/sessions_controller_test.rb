require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_session_path
    assert_response :success
  end

  test "should create session and send magic link" do
    user = users(:one)

    assert_emails 1 do
      post session_path, params: { session: { email: user.email } }
    end

    assert_redirected_to new_session_path
    assert_equal "Check your email for a magic link!", flash[:notice]
  end

  test "should create user on first login" do
    assert_difference "User.count", 1 do
      post session_path, params: { session: { email: "newuser@example.com" } }
    end

    assert_redirected_to new_session_path
  end

  test "should verify magic link and log in" do
    user = users(:one)
    team = teams(:one)
    token = user.generate_magic_link_token

    get verify_magic_link_path(token: token)

    # User has multiple teams, so redirects to teams index or first team
    # (with multiple teams from fixtures, redirects to teams index)
    assert_response :redirect
    assert_equal user.id, session[:user_id]
  end

  test "should reject invalid magic link" do
    get verify_magic_link_path(token: "invalid_token")

    assert_redirected_to new_session_path
    assert_equal "Invalid or expired magic link", flash[:alert]
  end

  test "should destroy session" do
    user = users(:one)
    post session_path, params: { session: { email: user.email } }
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)

    delete session_path

    assert_redirected_to new_session_path
    assert_nil session[:user_id]
  end

  test "first login saves locale from Accept-Language header" do
    user = users(:not_onboarded)
    assert_nil user.locale

    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token), headers: { "Accept-Language" => "en-US,en;q=0.9" }

    user.reload
    assert_equal "en", user.locale
  end

  test "returning login does not overwrite existing locale" do
    user = users(:one)
    assert_equal "en", user.locale

    # Simulate the user having set their locale to es
    user.update_column(:locale, "es")

    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token), headers: { "Accept-Language" => "en-US,en;q=0.9" }

    user.reload
    assert_equal "es", user.locale
  end

  test "first magic link login triggers WelcomeNotifier" do
    assert_difference -> { Noticed::Event.where(type: "WelcomeNotifier").count }, 1 do
      post session_path, params: { session: { email: "brand-new-welcome@example.com" } }
    end
  end

  test "subsequent magic link logins do not re-send WelcomeNotifier" do
    existing = users(:one)
    assert_no_difference -> { Noticed::Event.where(type: "WelcomeNotifier").count } do
      post session_path, params: { session: { email: existing.email } }
    end
  end

  test "invitation link works even when a stale not-onboarded session cookie is present" do
    stale_user = users(:not_onboarded)
    post session_path, params: { session: { email: stale_user.email } }
    stale_token = stale_user.generate_magic_link_token
    get verify_magic_link_path(token: stale_token)
    assert_equal stale_user.id, session[:user_id]

    invitee  = User.create!(email: "fresh-invitee@example.com")
    inviter  = users(:two)
    team     = teams(:two)
    token    = invitee.signed_id(purpose: :magic_link, expires_in: 7.days)

    get verify_magic_link_path(
      token: token,
      team: team.slug,
      invited_by: inviter.id
    )

    assert_redirected_to onboarding_path
    assert_equal invitee.id, session[:user_id]
    assert invitee.reload.member_of?(team)
  end
end
