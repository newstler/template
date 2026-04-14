module Madmin
  class NoticedEventsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:notifications)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = resources.where(type: params[:type]) if params[:type].present?
      resources = resources.where(record_type: params[:record_type]) if params[:record_type].present?
      resources = resources.where("created_at >= ?", params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
      resources = resources.where("created_at <= ?", params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
      resources.reorder(sort_column => sort_direction)
    end
  end
end
