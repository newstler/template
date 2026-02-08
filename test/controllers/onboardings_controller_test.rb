require "test_helper"

class OnboardingsControllerTest < ActionDispatch::IntegrationTest
  test "redirects to login when not authenticated" do
    get onboarding_path
    assert_redirected_to new_session_path
  end

  test "shows onboarding form for un-onboarded user" do
    user = users(:not_onboarded)
    sign_in(user)

    get onboarding_path
    assert_response :success
  end

  test "redirects onboarded users away from onboarding" do
    user = users(:one)
    sign_in(user)

    get onboarding_path
    assert_redirected_to root_path
  end

  test "completes onboarding with name" do
    user = users(:not_onboarded)
    team = teams(:one)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "Alice Smith", team_name: "Alice's Team" } }

    user.reload
    team.reload
    assert_equal "Alice Smith", user.name
    assert user.onboarded?
    assert_redirected_to team_root_path(team)
  end

  test "updates team name when user is owner" do
    user = users(:not_onboarded)
    team = teams(:one)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "Alice", team_name: "New Team Name" } }

    team.reload
    assert_equal "New Team Name", team.name
  end

  test "renders form again when name is blank" do
    user = users(:not_onboarded)
    sign_in(user)

    patch onboarding_path, params: { onboarding: { name: "" } }

    assert_response :unprocessable_entity
  end
end
