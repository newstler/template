class Teams::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
  end

  def edit
  end

  def update
    if current_team.update(team_params)
      redirect_to team_settings_path(current_team), notice: t("controllers.teams.settings.update.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def team_params
    params.require(:team).permit(:name)
  end
end
