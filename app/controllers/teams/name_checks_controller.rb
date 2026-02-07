class Teams::NameChecksController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
    name = params[:name].to_s.strip
    taken = name.present? && Team.where.not(id: current_team.id).exists?(name: name)

    render json: { available: !taken }
  end
end
