class Teams::PricingController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
    @prices = Price.all
  end
end
