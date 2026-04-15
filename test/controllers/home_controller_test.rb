require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "shows team dashboard when authenticated with team" do
    user = users(:one)
    team = teams(:one)
    sign_in(user)

    get team_root_path(team.slug)
    assert_response :success
    assert_match I18n.t("home.index.total_members"), response.body
    assert_match I18n.t("home.index.total_chats"), response.body
  end

  test "time range selector defaults to 30d" do
    user = users(:one)
    team = teams(:one)
    sign_in(user)

    get team_root_path(team.slug)
    assert_select "option[selected][value='30d']"
  end

  test "time range selector respects ?range=" do
    user = users(:one)
    team = teams(:one)
    sign_in(user)

    get team_root_path(team.slug), params: { range: "7d" }
    assert_select "option[selected][value='7d']"
  end

  test "shows teams index when accessing root while authenticated with multiple teams" do
    user = users(:one)
    sign_in(user)

    get root_path
    assert_response :success
  end
end
