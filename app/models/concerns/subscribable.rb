module Subscribable
  extend ActiveSupport::Concern

  included do
    scope :subscribed, -> { where(subscription_status: %w[active trialing]) }
    scope :past_due, -> { where(subscription_status: "past_due") }
    scope :unsubscribed, -> { where(subscription_status: [ nil, "canceled", "incomplete_expired" ]) }
  end

  def subscribed?
    subscription_status.in?(%w[active trialing])
  end

  def subscription_active?
    subscribed?
  end

  def past_due?
    subscription_status == "past_due"
  end

  def trialing?
    subscription_status == "trialing"
  end

  def canceled?
    subscription_status == "canceled"
  end

  def create_or_get_stripe_customer
    return Stripe::Customer.retrieve(stripe_customer_id) if stripe_customer_id.present?

    customer = Stripe::Customer.create(
      name: name,
      metadata: { team_id: id, team_slug: slug }
    )
    update!(stripe_customer_id: customer.id)
    customer
  end

  def create_checkout_session(price_id:, success_url:, cancel_url:)
    customer = create_or_get_stripe_customer

    Stripe::Checkout::Session.create(
      customer: customer.id,
      mode: "subscription",
      line_items: [ { price: price_id, quantity: 1 } ],
      subscription_data: { trial_period_days: 30 },
      success_url: success_url,
      cancel_url: cancel_url
    )
  end

  def create_billing_portal_session(return_url:)
    Stripe::BillingPortal::Session.create(
      customer: stripe_customer_id,
      return_url: return_url
    )
  end

  def cancel_subscription!
    return unless stripe_subscription_id.present?

    Stripe::Subscription.update(stripe_subscription_id, cancel_at_period_end: true)
    sync_subscription_from_stripe!
  end

  def sync_subscription_from_stripe!
    return unless stripe_subscription_id.present?

    subscription = Stripe::Subscription.retrieve(stripe_subscription_id)
    update!(
      subscription_status: subscription.status,
      current_period_ends_at: Time.at(subscription.current_period_end).utc
    )
  end
end
