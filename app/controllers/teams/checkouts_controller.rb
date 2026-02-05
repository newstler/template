class Teams::CheckoutsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def create
    session = current_team.create_checkout_session(
      price_id: params[:price_id],
      success_url: team_billing_url(current_team),
      cancel_url: team_pricing_url(current_team)
    )
    redirect_to session.url, allow_other_host: true
  end
end
