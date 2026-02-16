class Teams::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def show
  end

  def edit
  end

  def update
    current_team.assign_attributes(team_params)

    if current_team.save
      redirect_to team_settings_path(current_team.slug), notice: t("controllers.teams.settings.update.notice")
    else
      @team_form = current_team.dup.tap { |t| t.errors.merge!(current_team.errors) }
      current_team.reload
      render :edit, status: :unprocessable_entity
    end
  end

  def regenerate_api_key
    current_team.regenerate_api_key!
    redirect_to team_settings_path(current_team), notice: t("controllers.teams.settings.regenerate_api_key.notice")
  end

  private

  def team_params
    params.require(:team).permit(:name, :logo, :remove_logo)
  end
end
