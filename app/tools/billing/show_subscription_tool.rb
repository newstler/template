# frozen_string_literal: true

module Billing
  class ShowSubscriptionTool < ApplicationTool
    description "Get the current team's subscription status (admin only)"

    annotations(
      title: "Show Subscription",
      read_only_hint: true,
      open_world_hint: false
    )

    def call
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required", code: "forbidden")
      end

      success_response({
        team_id: current_team.id,
        team_name: current_team.name,
        subscription_status: current_team.subscription_status,
        subscribed: current_team.subscribed?,
        cancel_at_period_end: current_team.cancel_at_period_end,
        cancellation_pending: current_team.cancellation_pending?,
        current_period_ends_at: format_timestamp(current_team.current_period_ends_at),
        stripe_customer_id: current_team.stripe_customer_id
      })
    end
  end
end
