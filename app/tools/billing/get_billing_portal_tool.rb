# frozen_string_literal: true

module Billing
  class GetBillingPortalTool < ApplicationTool
    description "Get a Stripe Billing Portal URL to manage subscription (admin only)"

    annotations(
      title: "Get Billing Portal",
      read_only_hint: true,
      open_world_hint: true
    )

    arguments do
      required(:return_url).filled(:string).description("URL to return to after managing billing")
    end

    def call(return_url:)
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required", code: "forbidden")
      end

      unless current_team.stripe_customer_id.present?
        return error_response("No billing account found. Subscribe to a plan first.", code: "not_found")
      end

      portal = current_team.create_billing_portal_session(return_url: return_url)

      success_response({
        portal_url: portal.url
      })
    end
  end
end
