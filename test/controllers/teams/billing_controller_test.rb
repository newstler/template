require "test_helper"

class Teams::BillingControllerTest < ActionDispatch::IntegrationTest
  test "redirects when not authenticated" do
    get team_billing_path(teams(:one))
    assert_response :redirect
  end

  test "redirects non-admin members" do
    sign_in(users(:one))
    # user_one is member (not admin) of team_two
    get team_billing_path(teams(:two))
    assert_redirected_to team_root_path(teams(:two))
  end

  test "shows billing page for admin without stripe customer" do
    sign_in(users(:one))
    get team_billing_path(teams(:one))
    assert_response :success
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end
