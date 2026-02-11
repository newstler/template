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
end
