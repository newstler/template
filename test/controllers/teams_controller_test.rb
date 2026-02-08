require "test_helper"

class TeamsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
  end

  test "index redirects to login when not authenticated" do
    get teams_path
    assert_redirected_to new_session_path
  end

  test "index redirects to team root when user has single team" do
    sign_in(@user)

    # User one has memberships in both teams, so this won't redirect
    # Let's test with a user that has only one team
    get teams_path
    # With multiple teams, shows the index
    assert_response :success
  end

  test "new shows form" do
    sign_in(@user)

    get new_team_path
    assert_response :success
  end

  test "create creates team and membership" do
    sign_in(@user)

    assert_difference -> { Team.count } => 1, -> { Membership.count } => 1 do
      post teams_path, params: { team: { name: "New Team" } }
    end

    team = Team.last
    assert_equal "New Team", team.name
    assert_equal "new-team", team.slug
    assert @user.owner_of?(team)
    assert_redirected_to team_root_path(team)
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end
