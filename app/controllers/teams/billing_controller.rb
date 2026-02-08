class Teams::BillingController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
    if current_team.stripe_customer_id.present?
      portal = current_team.create_billing_portal_session(
        return_url: team_billing_url(current_team)
      )
      @portal_url = portal.url
    end
  end
end
