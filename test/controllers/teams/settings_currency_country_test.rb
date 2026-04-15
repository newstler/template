require "test_helper"

module Teams
  class SettingsCurrencyCountryTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:one)
      @team = teams(:one)
      sign_in @user
    end

    test "team admin can update default_currency and country_code" do
      patch team_settings_path(@team.slug), params: {
        team: { default_currency: "EUR", country_code: "DE" }
      }
      assert_response :redirect

      @team.reload
      assert_equal "EUR", @team.default_currency
      assert_equal "DE", @team.country_code
    end

    test "invalid country_code is rejected with a 422" do
      patch team_settings_path(@team.slug), params: {
        team: { country_code: "ZZ" }
      }
      assert_response :unprocessable_entity

      @team.reload
      assert_not_equal "ZZ", @team.country_code
    end

    test "invalid default_currency is rejected with a 422" do
      patch team_settings_path(@team.slug), params: {
        team: { default_currency: "XXX" }
      }
      assert_response :unprocessable_entity

      @team.reload
      assert_not_equal "XXX", @team.default_currency
    end
  end
end
