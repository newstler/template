require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "validates role inclusion" do
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

  test "owner? returns true for owner role" do
    membership = memberships(:user_one_team_one)
    assert membership.owner?
  end

  test "admin? returns true for admin and owner roles" do
    owner = memberships(:user_one_team_one)
    assert owner.admin?

    member = memberships(:user_one_team_two)
    assert_not member.admin?
  end

  test "member? returns true for member role" do
    member = memberships(:user_one_team_two)
    assert member.member?

    owner = memberships(:user_one_team_one)
    assert_not owner.member?
  end

  test "belongs to user" do
    membership = memberships(:user_one_team_one)
    assert_respond_to membership, :user
  end

  test "belongs to team" do
    membership = memberships(:user_one_team_one)
    assert_respond_to membership, :team
  end

  test "belongs to invited_by optionally" do
    membership_with_inviter = memberships(:user_one_team_two)
    assert membership_with_inviter.invited_by.present?

    membership_without_inviter = memberships(:user_one_team_one)
    assert_nil membership_without_inviter.invited_by
  end
end
