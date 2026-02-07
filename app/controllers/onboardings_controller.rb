class OnboardingsController < ApplicationController
  skip_before_action :require_onboarding!
  before_action :authenticate_user!
  before_action :redirect_if_onboarded
  layout "onboarding"

  def show
    @user = current_user
    @team = current_user.teams.first
  end

  def update
    @user = current_user
    @team = current_user.teams.first

    ActiveRecord::Base.transaction do
      @user.update!(name: onboarding_params[:name])
      @team.update!(name: onboarding_params[:team_name]) if @team && @user.owner_of?(@team) && onboarding_params[:team_name].present?
    end

    redirect_to team_root_path(@team), notice: t("controllers.onboardings.update.notice", name: @user.name)
  rescue ActiveRecord::RecordInvalid
    render :show, status: :unprocessable_entity
  end

  private

  def onboarding_params
    params.require(:onboarding).permit(:name, :team_name)
  end

  def redirect_if_onboarded
    redirect_to root_path if current_user.onboarded?
  end
end
