class Webhooks::StripeController < ActionController::Base
  skip_forgery_protection

  def create
    payload = request.body.read
    sig_header = request.env["HTTP_STRIPE_SIGNATURE"]

    begin
      event = Stripe::Webhook.construct_event(
        payload, sig_header, Setting.get(:stripe_webhook_secret)
      )
    rescue JSON::ParserError, Stripe::SignatureVerificationError
      head :bad_request
      return
    end

    case event.type
    when "checkout.session.completed"
      handle_checkout_completed(event.data.object)
    when "customer.subscription.updated"
      handle_subscription_updated(event.data.object)
    when "customer.subscription.deleted"
      handle_subscription_deleted(event.data.object)
    end

    head :ok
  end

  private

  def handle_checkout_completed(session)
    team = Team.find_by(stripe_customer_id: session.customer)
    return unless team

    team.update!(stripe_subscription_id: session.subscription)
    team.sync_subscription_from_stripe!
  end

  def handle_subscription_updated(subscription)
    team = Team.find_by(stripe_customer_id: subscription.customer)
    return unless team

    team.update!(stripe_subscription_id: subscription.id) unless team.stripe_subscription_id.present?
    team.sync_subscription_from_stripe!
  end

  def handle_subscription_deleted(subscription)
    team = Team.find_by(stripe_customer_id: subscription.customer)
    return unless team

    team.update!(
      subscription_status: "canceled",
      stripe_subscription_id: nil,
      cancel_at_period_end: false
    )
  end
end
