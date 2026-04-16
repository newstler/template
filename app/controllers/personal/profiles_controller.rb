module Personal
  class ProfilesController < ApplicationController
    before_action :authenticate_user!

    def edit
      @user = current_user
      @languages = Language.enabled.by_name
    end

    def update
      @user = current_user

      if @user.update(profile_params)
        redirect_to personal_home_path, notice: t("controllers.profiles.update.notice")
      else
        @languages = Language.enabled.by_name
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def profile_params
      params.require(:user).permit(
        :name,
        :locale,
        :avatar,
        :remove_avatar,
        :preferred_currency,
        :residence_country_code
      )
    end
  end
end
