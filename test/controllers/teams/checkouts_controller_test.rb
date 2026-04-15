require "test_helper"

class Teams::CheckoutsControllerTest < ActionDispatch::IntegrationTest
  test "redirects when not authenticated" do
    post team_checkout_path(teams(:one)), params: { price_id: "price_123" }
    assert_response :redirect
  end

  test "redirects non-admin members" do
    sign_in(users(:one))
    # user_one is member (not admin) of team_two
    post team_checkout_path(teams(:two)), params: { price_id: "price_123" }
    assert_redirected_to team_root_path(teams(:two))
  end

  test "redirects to team root when Stripe is not configured" do
    sign_in(users(:one))
    Setting.instance.update!(stripe_secret_key: nil)
    post team_checkout_path(teams(:one)), params: { price_id: "price_123" }
    assert_redirected_to team_root_path(teams(:one))
    assert_equal I18n.t("controllers.application.stripe_not_configured"), flash[:alert]
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end
