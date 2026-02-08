# frozen_string_literal: true

module Billing
  class ResumeSubscriptionTool < ApplicationTool
    description "Resume a canceled subscription before the billing period ends (admin only)"

    annotations(
      title: "Resume Subscription",
      read_only_hint: false,
      open_world_hint: true
    )

    def call
      require_user!

      membership = current_user.membership_for(current_team)
      unless membership&.admin?
        return error_response("Admin access required", code: "forbidden")
      end

      unless current_team.cancellation_pending?
        return error_response("No pending cancellation to resume", code: "not_found")
      end

      current_team.resume_subscription!

      success_response({
        subscription_status: current_team.subscription_status,
        cancel_at_period_end: current_team.cancel_at_period_end,
        current_period_ends_at: format_timestamp(current_team.current_period_ends_at)
      }, message: "Subscription resumed successfully")
    end
  end
end
