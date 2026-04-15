module Madmin
  class AiModelsController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
      @available_models = Model.enabled.order(:provider, :name).pluck(:name, :model_id)
    end

    def edit
      @setting = Setting.instance
      @available_models = Model.enabled.order(:provider, :name).pluck(:name, :model_id)
    end

    def update
      @setting = Setting.instance

      if @setting.update(ai_model_params)
        redirect_to main_app.madmin_ai_models_path, notice: t("controllers.madmin.ai_models.update.notice")
      else
        @available_models = Model.enabled.order(:provider, :name).pluck(:name, :model_id)
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def ai_model_params
      params.require(:setting).permit(
        :default_model,
        :translation_model,
        :moderation_model,
        :embedding_model,
        :rrf_k,
        :currencylayer_api_key,
        :default_currency,
        :default_country_code,
        :search_tokenizer,
        :conversation_digest_window_minutes
      )
    end
  end
end
