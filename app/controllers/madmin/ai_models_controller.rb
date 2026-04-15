module Madmin
  class AiModelsController < Madmin::ApplicationController
    def show
      @setting = Setting.instance
      @available_models = Model.enabled.order(:provider, :name).pluck(:name, :model_id)
      @embedding_models = Model.enabled.embedding.order(:provider, :name).pluck(:model_id)
      load_models_table
    end

    def update
      @setting = Setting.instance

      if @setting.update(ai_model_params)
        respond_to do |format|
          format.json { head :ok }
          format.html { redirect_to main_app.madmin_ai_models_path, notice: t("controllers.madmin.ai_models.update.notice") }
        end
      else
        respond_to do |format|
          format.json { head :unprocessable_entity }
          format.html do
            @available_models = Model.enabled.order(:provider, :name).pluck(:name, :model_id)
            @embedding_models = Model.enabled.embedding.order(:provider, :name).pluck(:model_id)
            render :edit, status: :unprocessable_entity
          end
        end
      end
    end

    def refresh_all
      Model.refresh!
      redirect_to main_app.madmin_ai_models_path(tab: "available"), notice: "Models refreshed! Total: #{Model.count}"
    end

    private

    def load_models_table
      models = Model.enabled.order(:provider, :name)
      models = models.where(provider: params[:provider]) if params[:provider].present?
      if params[:q].present?
        models = models.where("name LIKE ? OR model_id LIKE ?", "%#{params[:q]}%", "%#{params[:q]}%")
      end
      @pagy, @models = pagy(models, limit: 25)
      @providers_list = Model.enabled.distinct.order(:provider).pluck(:provider)
    end

    def ai_model_params
      params.require(:setting).permit(
        :default_model,
        :translation_model,
        :moderation_model,
        :embedding_model
      )
    end
  end
end
