module Madmin
  class ModelsController < Madmin::ResourceController
    COMPUTED_SORTS = %w[chats_count usage_cost].freeze

    skip_before_action :set_record, only: [ :refresh_all ]

    def refresh_all
      RubyLLM.models.refresh
      redirect_to resource.index_path, notice: t("controllers.madmin.models.refresh.notice", count: RubyLLM::ActiveRecord::Model.listed.count)
    end

    private

    def set_record
      @record = resource.model.with_usage_cost.find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope).enabled
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.where(provider: params[:provider]) if params[:provider].present?
      resources = resources.with_usage_cost
      @providers = resource.model.enabled.distinct.order(:provider).pluck(:provider)

      return resources if sort_column.blank?

      if COMPUTED_SORTS.include?(sort_column)
        resources.reorder(Arel.sql("#{sort_column} #{sort_direction == 'asc' ? 'ASC' : 'DESC'}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
