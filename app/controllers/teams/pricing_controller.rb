class Teams::PricingController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
    @prices = Price.all
    @monthly_prices = @prices.select { |p| p.interval == "month" }
    @yearly_prices = @prices.select { |p| p.interval == "year" }
  end
end
