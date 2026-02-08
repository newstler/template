require "test_helper"

class SubscribableTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one)
  end

  test "subscribed? returns true for active status" do
    @team.update!(subscription_status: "active")
    assert @team.subscribed?
  end

  test "subscribed? returns true for trialing status" do
    @team.update!(subscription_status: "trialing")
    assert @team.subscribed?
  end

  test "subscribed? returns false for nil status" do
    @team.update!(subscription_status: nil)
    assert_not @team.subscribed?
  end

  test "subscribed? returns false for canceled status" do
    @team.update!(subscription_status: "canceled")
    assert_not @team.subscribed?
  end

  test "subscription_active? delegates to subscribed?" do
    @team.update!(subscription_status: "active")
    assert @team.subscription_active?
  end

  test "past_due? returns true for past_due status" do
    @team.update!(subscription_status: "past_due")
    assert @team.past_due?
  end

  test "past_due? returns false for active status" do
    @team.update!(subscription_status: "active")
    assert_not @team.past_due?
  end

  test "trialing? returns true for trialing status" do
    @team.update!(subscription_status: "trialing")
    assert @team.trialing?
  end

  test "canceled? returns true for canceled status" do
    @team.update!(subscription_status: "canceled")
    assert @team.canceled?
  end

  test "subscribed scope returns active and trialing teams" do
    @team.update!(subscription_status: "active")
    teams(:two).update!(subscription_status: "canceled")

    assert_includes Team.subscribed, @team
    assert_not_includes Team.subscribed, teams(:two)
  end

  test "past_due scope returns past_due teams" do
    @team.update!(subscription_status: "past_due")
    assert_includes Team.past_due, @team
  end

  test "unsubscribed scope returns nil and canceled teams" do
    @team.update!(subscription_status: nil)
    teams(:two).update!(subscription_status: "canceled")

    assert_includes Team.unsubscribed, @team
    assert_includes Team.unsubscribed, teams(:two)
  end

  test "cancellation_pending? is true when active and cancel_at_period_end" do
    @team.update!(subscription_status: "active", cancel_at_period_end: true)
    assert @team.cancellation_pending?
  end

  test "cancellation_pending? is false when active without cancel_at_period_end" do
    @team.update!(subscription_status: "active", cancel_at_period_end: false)
    assert_not @team.cancellation_pending?
  end

  test "cancellation_pending? is false when canceled" do
    @team.update!(subscription_status: "canceled", cancel_at_period_end: true)
    assert_not @team.cancellation_pending?
  end

  test "cancellation_pending? is false when trialing" do
    @team.update!(subscription_status: "trialing", cancel_at_period_end: true)
    assert_not @team.cancellation_pending?
  end

  test "subscribed? still returns true when cancellation is pending" do
    @team.update!(subscription_status: "active", cancel_at_period_end: true)
    assert @team.subscribed?
  end
end
