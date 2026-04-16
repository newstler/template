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

  test "redirects to team root when Stripe is not configured" do
    sign_in(users(:one))
    Setting.instance.update!(stripe_secret_key: nil)
    get team_billing_path(teams(:one))
    assert_redirected_to team_root_path(teams(:one))
    assert_equal I18n.t("controllers.application.stripe_not_configured"), flash[:alert]
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end
