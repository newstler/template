class Models::RefreshesController < ApplicationController
  before_action :authenticate_admin!

  def create
    RubyLLM.models.refresh
    redirect_to team_models_path(current_team), notice: t("controllers.models.refreshes.create.notice")
  end
end
