class TeamsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_multi_tenant!, only: [ :new, :create ]

  def index
    @teams = current_user.teams

    if @teams.one?
      redirect_to team_root_path(@teams.first)
    elsif @teams.none?
      team = create_personal_team(current_user)
      redirect_to team_root_path(team)
    end
  end

  def new
    @team = Team.new
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      @team.memberships.create!(user: current_user, role: "owner")
      redirect_to team_root_path(@team), notice: t("controllers.teams.create.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def team_params
    params.require(:team).permit(:name)
  end

  def require_multi_tenant!
    redirect_to root_path unless Team.multi_tenant?
  end

  def create_personal_team(user)
    team = Team.create!(name: "#{user.name || user.email.split('@').first}'s Team")
    team.memberships.create!(user: user, role: "owner")
    team
  end
end
