require "test_helper"

class Personal::HomeControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get personal_home_path
    assert_redirected_to new_session_path
  end

  test "renders for authenticated user" do
    sign_in(users(:one))

    get personal_home_path

    assert_response :success
    assert_select "h1", text: /#{users(:one).name}/
  end

  test "lists user teams alphabetically" do
    sign_in(users(:one))

    get personal_home_path

    body = response.body
    team_one_pos = body.index(teams(:one).name)
    team_two_pos = body.index(teams(:two).name)
    assert team_one_pos && team_two_pos, "both team names should appear on the page"
    assert team_one_pos < team_two_pos, "Team One should appear before Team Two"
  end

  test "renders member counts using pluralized i18n" do
    sign_in(users(:one))

    get personal_home_path

    member_count_for_team_one = Membership.where(team: teams(:one)).count
    assert_select "p", text: /#{member_count_for_team_one} member/
  end

  test "shows create-team CTA when user owns no team" do
    sign_in(users(:three))

    get personal_home_path

    assert_response :success
    assert_select "a[href=?]", new_team_path
  end

  test "hides create-team CTA when user already owns a team" do
    sign_in(users(:one))

    get personal_home_path

    assert_response :success
    assert_select "a[href=?]", new_team_path, count: 0
  end
end
