require "test_helper"

class Teams::SubscriptionCancellationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    @admin = users(:one)
  end

  test "redirects when not authenticated" do
    post team_subscription_cancellation_path(@team)
    assert_response :redirect
  end

  test "redirects non-admin members on create" do
    sign_in(users(:one))
    # user_one is member (not admin) of team_two
    post team_subscription_cancellation_path(teams(:two))
    assert_redirected_to team_root_path(teams(:two))
  end

  test "create cancels subscription and redirects to billing" do
    @team.update!(stripe_subscription_id: "sub_test123", subscription_status: "active")
    sign_in(@admin)

    stub_stripe_cancel do
      post team_subscription_cancellation_path(@team)
    end

    assert_redirected_to team_billing_path(@team)
    assert flash[:notice].present?
  end

  test "redirects non-admin members on destroy" do
    sign_in(users(:one))
    delete team_subscription_cancellation_path(teams(:two))
    assert_redirected_to team_root_path(teams(:two))
  end

  test "destroy resumes subscription and redirects to billing" do
    @team.update!(stripe_subscription_id: "sub_test123", subscription_status: "active", cancel_at_period_end: true)
    sign_in(@admin)

    stub_stripe_resume do
      delete team_subscription_cancellation_path(@team)
    end

    assert_redirected_to team_billing_path(@team)
    assert flash[:notice].present?
  end

  private

  def sign_in(user)
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end

  def stub_stripe_cancel(&block)
    stub_stripe_subscription_update(cancel_at_period_end: true, &block)
  end

  def stub_stripe_resume(&block)
    stub_stripe_subscription_update(cancel_at_period_end: false, &block)
  end

  def stub_stripe_subscription_update(cancel_at_period_end:)
    items = Struct.new(:data).new([ { "current_period_end" => 1700000000 } ])
    subscription = Struct.new(:status, :cancel_at_period_end, :items)
      .new("active", cancel_at_period_end, items)

    original_update = Stripe::Subscription.method(:update)
    original_retrieve = Stripe::Subscription.method(:retrieve)

    Stripe::Subscription.define_singleton_method(:update) { |*, **| subscription }
    Stripe::Subscription.define_singleton_method(:retrieve) { |*, **| subscription }

    yield
  ensure
    Stripe::Subscription.define_singleton_method(:update, original_update)
    Stripe::Subscription.define_singleton_method(:retrieve, original_retrieve)
  end
end
