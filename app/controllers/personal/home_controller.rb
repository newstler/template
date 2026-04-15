module Personal
  class HomeController < ApplicationController
    before_action :authenticate_user!

    def show
      @teams = current_user.teams.includes(logo_attachment: :blob).order(:name)
      @team_member_counts = Membership.where(team_id: @teams.map(&:id)).group(:team_id).count
    end
  end
end
