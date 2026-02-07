require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
    sign_in(@user)
  end

  test "shows profile page" do
    get team_profile_path(@team)
    assert_response :success
  end

  test "shows edit profile form" do
    get edit_team_profile_path(@team)
    assert_response :success
  end

  test "updates profile name" do
    patch team_profile_path(@team), params: { user: { name: "Updated Name" } }

    @user.reload
    assert_equal "Updated Name", @user.name
    assert_redirected_to team_profile_path(@team)
  end

  test "redirects when not authenticated" do
    delete session_path
    get team_profile_path(@team)
    assert_response :redirect
  end
end
