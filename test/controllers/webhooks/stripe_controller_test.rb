require "test_helper"

class Webhooks::StripeControllerTest < ActionDispatch::IntegrationTest
  test "returns bad_request for invalid signature" do
    post webhooks_stripe_path,
      params: "{}",
      headers: {
        "CONTENT_TYPE" => "application/json",
        "HTTP_STRIPE_SIGNATURE" => "invalid"
      }
    assert_response :bad_request
  end

  test "handles checkout.session.completed event" do
    team = teams(:one)
    team.update!(stripe_customer_id: "cus_test123")

    event_data = {
      type: "checkout.session.completed",
      data: {
        object: {
          customer: "cus_test123",
          subscription: "sub_test456"
        }
      }
    }
    event = Stripe::Event.construct_from(event_data)

    stub_webhook_and_post(event, event_data) do
      # Also stub the sync call
      team.define_singleton_method(:sync_subscription_from_stripe!) do
        update!(subscription_status: "active", current_period_ends_at: Time.utc(2026, 3, 1))
      end
      Team.define_singleton_method(:find_by) do |**args|
        args[:stripe_customer_id] == "cus_test123" ? team : nil
      end
    end

    team.reload
    assert_equal "sub_test456", team.stripe_subscription_id
  ensure
    Team.singleton_class.remove_method(:find_by) if Team.singleton_class.method_defined?(:find_by, false)
  end

  test "handles customer.subscription.updated event" do
    team = teams(:one)
    team.update!(stripe_customer_id: "cus_test123", stripe_subscription_id: "sub_test456")

    event_data = {
      type: "customer.subscription.updated",
      data: {
        object: {
          customer: "cus_test123",
          status: "past_due",
          current_period_end: 1700000000
        }
      }
    }
    event = Stripe::Event.construct_from(event_data)

    stub_webhook_and_post(event, event_data)

    team.reload
    assert_equal "past_due", team.subscription_status
  end

  test "handles customer.subscription.deleted event" do
    team = teams(:one)
    team.update!(stripe_customer_id: "cus_test123", stripe_subscription_id: "sub_test456", subscription_status: "active")

    event_data = {
      type: "customer.subscription.deleted",
      data: {
        object: {
          customer: "cus_test123"
        }
      }
    }
    event = Stripe::Event.construct_from(event_data)

    stub_webhook_and_post(event, event_data)

    team.reload
    assert_equal "canceled", team.subscription_status
    assert_nil team.stripe_subscription_id
  end

  private

  def stub_webhook_and_post(event, event_data)
    original = Stripe::Webhook.method(:construct_event)
    Stripe::Webhook.define_singleton_method(:construct_event) { |*, **| event }

    yield if block_given?

    post webhooks_stripe_path,
      params: event_data.to_json,
      headers: { "CONTENT_TYPE" => "application/json", "HTTP_STRIPE_SIGNATURE" => "valid" }
    assert_response :ok
  ensure
    Stripe::Webhook.define_singleton_method(:construct_event, original)
  end
end
