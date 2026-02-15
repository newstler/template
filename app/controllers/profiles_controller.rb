class ProfilesController < ApplicationController
  before_action :authenticate_user!

  def show
    @user = current_user
    @user_language = Language.find_by(code: @user.locale) if @user.locale.present?
  end

  def edit
    @user = current_user
    @languages = Language.enabled.by_name
  end

  def update
    @user = current_user

    if @user.update(profile_params)
      redirect_to team_profile_path(current_team), notice: t("controllers.profiles.update.notice")
    else
      @languages = Language.enabled.by_name
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :locale)
  end
end
