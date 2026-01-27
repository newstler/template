module Madmin
  class ModelsController < Madmin::ResourceController
    skip_before_action :set_record, only: [:refresh_all]

    def scoped_resources
      resources = super.enabled
      resources = resources.where(provider: params[:provider]) if params[:provider].present?
      resources
    end

    def refresh_all
      Model.refresh!
      redirect_to resource.index_path, notice: "Models refreshed! Total: #{Model.count}"
    end
  end
end
