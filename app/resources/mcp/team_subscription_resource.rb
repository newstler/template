# frozen_string_literal: true

module Mcp
  class TeamSubscriptionResource < ApplicationResource
    uri "app:///subscription"
    resource_name "Team Subscription"
    description "Team subscription status. Use show_subscription tool for authenticated access."
    mime_type "application/json"

    def content
      to_json({
        message: "Use the 'show_subscription' tool for authenticated subscription info",
        tool: "show_subscription"
      })
    end
  end
end
