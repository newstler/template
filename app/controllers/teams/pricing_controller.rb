class Teams::PricingController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
    @prices = Price.all
    @monthly_prices, @yearly_prices = @prices.partition { |p| p.interval == "month" }
  end
end
