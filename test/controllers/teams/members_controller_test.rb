require "test_helper"

class Teams::MembersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
    sign_in(@user)
  end

  test "shows members index" do
    get team_members_path(@team)
    assert_response :success
  end

  test "shows member profile" do
    membership = memberships(:user_one_team_one)
    get team_member_path(@team, membership)
    assert_response :success
  end
end
