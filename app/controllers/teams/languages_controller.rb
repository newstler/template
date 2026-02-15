class Teams::LanguagesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_team_admin!

  def index
    @active_languages = current_team.team_languages.active.includes(:language).map(&:language)
    @available_languages = Language.enabled.where.not(id: @active_languages.map(&:id)).by_name
  end

  def create
    language = Language.enabled.find(params[:language_id])
    current_team.enable_language!(language)
    BackfillTranslationsJob.perform_later(current_team.id, language.code)
    redirect_to team_languages_path(current_team), notice: t("controllers.teams.languages.create.notice", language: language.localized_name)
  end

  def destroy
    language = Language.find(params[:id])

    if current_team.team_languages.active.count <= 1
      redirect_to team_languages_path(current_team), alert: t("controllers.teams.languages.destroy.cannot_remove_last")
      return
    end

    current_team.disable_language!(language)
    redirect_to team_languages_path(current_team), notice: t("controllers.teams.languages.destroy.notice", language: language.localized_name)
  end
end
