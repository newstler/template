require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows home page when authenticated" do
    user = users(:one)
    post session_path, params: { session: { email: user.email } }
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)

    get root_path
    assert_response :success
  end
end
