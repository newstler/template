require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "rejects unknown role values" do
    membership = Membership.new(user: users(:one), team: teams(:two), role: "invalid")
    assert_not membership.valid?
    assert_includes membership.errors[:role], "is not included in the list"
  end

  test "validates uniqueness of user per team" do
    existing = memberships(:user_one_team_one)
    membership = Membership.new(user: existing.user, team: existing.team, role: "member")
    assert_not membership.valid?
    assert_includes membership.errors[:user_id], "has already been taken"
  end

  test "role predicates distinguish owner, admin, and member" do
    owner = memberships(:user_one_team_one)
    member = memberships(:user_one_team_two)

    assert owner.owner?
    assert owner.admin?
    assert_not owner.member?

    assert member.member?
    assert_not member.admin?
    assert_not member.owner?
  end
end
