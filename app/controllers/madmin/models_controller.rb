module Madmin
  class ModelsController < Madmin::ResourceController
    def scoped_resources
      resources = super.enabled
      resources = resources.where(provider: params[:provider]) if params[:provider].present?
      resources
    end

    def refresh_all
      Model.refresh!
      redirect_to madmin_models_path, notice: "Models refreshed! Total: #{Model.count}"
    end
  end
end
