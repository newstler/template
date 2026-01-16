require "test_helper"

class Admins::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get new_admins_session_path
    assert_response :success
  end

  test "should create session and send magic link for existing admin" do
    admin = admins(:one)

    assert_emails 1 do
      post admins_session_path, params: { session: { email: admin.email } }
    end

    assert_redirected_to new_admins_session_path
    assert_equal "Check your email for a magic link!", flash[:notice]
  end

  test "should not create session for non-existent admin" do
    post admins_session_path, params: { session: { email: "notadmin@example.com" } }

    assert_redirected_to new_admins_session_path
    assert_equal "Admin not found. Only existing admins can log in.", flash[:alert]
  end

  test "should verify magic link and log in" do
    admin = admins(:one)
    token = admin.generate_magic_link_token

    get admins_verify_magic_link_path(token: token)

    assert_redirected_to madmin_root_path
    assert_equal admin.id, session[:admin_id]
  end
end
