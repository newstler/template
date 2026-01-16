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
    token = user.generate_magic_link_token

    get verify_magic_link_path(token: token)

    assert_redirected_to root_path
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

    assert_redirected_to root_path
    assert_nil session[:user_id]
  end
end
