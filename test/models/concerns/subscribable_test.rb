require "test_helper"

class SubscribableTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one)
  end

  test "subscribed? covers active and trialing, not canceled, past_due, or nil" do
    @team.update!(subscription_status: "active")
    assert @team.subscribed?
    assert @team.subscription_active?

    @team.update!(subscription_status: "trialing")
    assert @team.subscribed?

    @team.update!(subscription_status: "canceled")
    assert_not @team.subscribed?

    @team.update!(subscription_status: nil)
    assert_not @team.subscribed?
  end

  test "status predicates match their column values" do
    @team.update!(subscription_status: "past_due")
    assert @team.past_due?

    @team.update!(subscription_status: "trialing")
    assert @team.trialing?

    @team.update!(subscription_status: "canceled")
    assert @team.canceled?

    @team.update!(subscription_status: "active")
    assert_not @team.past_due?
  end

  test "subscribed/past_due/unsubscribed scopes partition teams by status" do
    @team.update!(subscription_status: "active")
    teams(:two).update!(subscription_status: "canceled")

    assert_includes Team.subscribed, @team
    assert_not_includes Team.subscribed, teams(:two)

    @team.update!(subscription_status: "past_due")
    assert_includes Team.past_due, @team

    @team.update!(subscription_status: nil)
    assert_includes Team.unsubscribed, @team
    assert_includes Team.unsubscribed, teams(:two)
  end

  test "cancellation_pending? requires active status and cancel_at_period_end" do
    @team.update!(subscription_status: "active", cancel_at_period_end: true)
    assert @team.cancellation_pending?
    assert @team.subscribed?, "still subscribed until the period actually ends"

    @team.update!(subscription_status: "active", cancel_at_period_end: false)
    assert_not @team.cancellation_pending?

    @team.update!(subscription_status: "canceled", cancel_at_period_end: true)
    assert_not @team.cancellation_pending?

    @team.update!(subscription_status: "trialing", cancel_at_period_end: true)
    assert_not @team.cancellation_pending?
  end
end
