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
end
