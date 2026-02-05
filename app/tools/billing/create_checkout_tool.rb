# frozen_string_literal: true

module Billing
  class CreateCheckoutTool < ApplicationTool
    description "Create a Stripe Checkout session for subscription (admin only)"

    annotations(
      title: "Create Checkout",
      read_only_hint: false,
      open_world_hint: true
    )

    arguments do
      required(:price_id).filled(:string).description("Stripe price ID to subscribe to")
      required(:success_url).filled(:string).description("URL to redirect after successful checkout")
      required(:cancel_url).filled(:string).description("URL to redirect if checkout is canceled")
    end

    def call(price_id:, success_url:, cancel_url:)
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required", code: "forbidden")
      end

      session = current_team.create_checkout_session(
        price_id: price_id,
        success_url: success_url,
        cancel_url: cancel_url
      )

      success_response({
        checkout_url: session.url,
        session_id: session.id
      })
    end
  end
end
