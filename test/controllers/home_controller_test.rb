require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows team home page when authenticated with team" do
    user = users(:one)
    team = teams(:one)
    sign_in(user)

    get team_root_path(team)
    assert_response :success
  end

  test "shows teams index when accessing root while authenticated with multiple teams" do
    user = users(:one) # User one has 2 teams per fixtures
    sign_in(user)

    get root_path
    # With multiple teams, shows the team selection page
    assert_response :success
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end
