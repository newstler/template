require "test_helper"

class CountryableTest < ActiveSupport::TestCase
  test "User#country returns an ISO3166::Country when code is set" do
    user = users(:one)
    user.update!(residence_country_code: "US")
    assert_kind_of ISO3166::Country, user.country
    assert_equal "US", user.country.alpha2
  end

  test "User#country is nil when code is blank" do
    user = users(:one)
    user.update!(residence_country_code: nil)
    assert_nil user.country
    assert_nil user.country_name
    assert_nil user.country_flag
  end

  test "User#country_name is localized" do
    user = users(:one)
    user.update!(residence_country_code: "DE")
    I18n.with_locale(:en) { assert_equal "Germany", user.country_name }
  end

  test "User#country_flag returns an emoji flag" do
    user = users(:one)
    user.update!(residence_country_code: "JP")
    assert_equal "🇯🇵", user.country_flag
  end

  test "Team also gets Countryable via its own column" do
    team = teams(:one)
    team.update!(country_code: "GB")
    assert_equal "GB", team.country.alpha2
  end

  test "Team validates country_code against ISO3166 codes" do
    team = teams(:one)
    team.country_code = "ZZ"
    assert_not team.valid?
  end
end
