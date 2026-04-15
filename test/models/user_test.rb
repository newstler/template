require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "onboarded? returns true when name is present" do
    user = users(:one)
    assert user.onboarded?
  end

  test "onboarded? returns false when name is blank" do
    user = users(:not_onboarded)
    assert_not user.onboarded?
  end

  test "can be created without a name" do
    user = User.create!(email: "noname@example.com")
    assert user.persisted?
    assert_nil user.name
  end

  test "locale validates against enabled language codes" do
    user = users(:one)
    user.locale = "en"
    assert user.valid?

    user.locale = "xx"
    assert_not user.valid?
    assert user.errors[:locale].any?
  end

  test "locale allows nil" do
    user = users(:one)
    user.locale = nil
    assert user.valid?
  end

  test "blank locale is nilified before validation" do
    user = users(:one)
    user.locale = ""
    assert user.valid?
    assert_nil user.locale
  end

  test "effective_locale returns stored locale when set" do
    user = users(:one)
    user.locale = "es"
    assert_equal :es, user.effective_locale
  end

  test "effective_locale returns fallback when locale is nil" do
    user = users(:not_onboarded)
    assert_equal :en, user.effective_locale
    assert_equal :fr, user.effective_locale(fallback: :fr)
  end

  test "notification_preferences defaults to an empty hash" do
    user = User.create!(email: "prefs@example.com")
    assert_equal({}, user.notification_preferences)
  end

  test "notification_preferences can store per-kind per-channel toggles" do
    user = users(:one)
    user.update!(notification_preferences: { "welcome" => { "email" => false } })
    user.reload
    assert_equal false, user.notification_preferences.dig("welcome", "email")
  end

  test "preferred_currency is nullable" do
    user = users(:one)
    assert_nil user.preferred_currency
  end

  test "preferred_currency must be a supported code if set" do
    user = users(:one)
    user.preferred_currency = "USD"
    assert user.valid?
    user.preferred_currency = "XXX"
    assert_not user.valid?
    assert user.errors[:preferred_currency].any?
  end

  test "residence_country_code is nullable" do
    user = users(:one)
    assert_nil user.residence_country_code
    assert user.valid?
  end

  test "residence_country_code must be a valid ISO 3166 alpha-2 when set" do
    user = users(:one)
    user.residence_country_code = "US"
    assert user.valid?
    user.residence_country_code = "ZZ"
    assert_not user.valid?
    assert user.errors[:residence_country_code].any?
  end

  test "owner? is true when user owns at least one team" do
    assert users(:one).owner?
  end

  test "owner? is false when user is only a member" do
    assert_not users(:three).owner?
  end

  test "owner? is false when user has no memberships" do
    user = User.create!(email: "loner@example.com")
    assert_not user.owner?
  end
end
