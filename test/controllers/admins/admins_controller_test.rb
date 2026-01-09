require "test_helper"

class Admins::AdminsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admins_admins_index_url
    assert_response :success
  end

  test "should get new" do
    get admins_admins_new_url
    assert_response :success
  end

  test "should get create" do
    get admins_admins_create_url
    assert_response :success
  end

  test "should get destroy" do
    get admins_admins_destroy_url
    assert_response :success
  end
end
