require "test_helper"

class Admins::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get admins_sessions_new_url
    assert_response :success
  end

  test "should get create" do
    get admins_sessions_create_url
    assert_response :success
  end
end
