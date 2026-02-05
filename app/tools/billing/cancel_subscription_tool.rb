# frozen_string_literal: true

module Billing
  class CancelSubscriptionTool < ApplicationTool
    description "Cancel team subscription at end of billing period (admin only)"

    annotations(
      title: "Cancel Subscription",
      read_only_hint: false,
      open_world_hint: true
    )

    def call
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required", code: "forbidden")
      end

      unless current_team.stripe_subscription_id.present?
        return error_response("No active subscription to cancel", code: "not_found")
      end

      current_team.cancel_subscription!

      success_response({
        subscription_status: current_team.subscription_status,
        current_period_ends_at: format_timestamp(current_team.current_period_ends_at)
      }, message: "Subscription will be canceled at end of billing period")
    end
  end
end
