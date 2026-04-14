require "test_helper"

class ProfilesCurrencyCountryTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
    sign_in @user
  end

  test "user can update preferred_currency and residence_country_code" do
    patch team_profile_path(@team.slug), params: {
      user: { preferred_currency: "EUR", residence_country_code: "DE" }
    }
    assert_response :redirect

    @user.reload
    assert_equal "EUR", @user.preferred_currency
    assert_equal "DE", @user.residence_country_code
  end

  test "invalid preferred_currency is rejected" do
    patch team_profile_path(@team.slug), params: {
      user: { preferred_currency: "XXX" }
    }
    assert_response :unprocessable_entity

    @user.reload
    assert_nil @user.preferred_currency
  end
end
