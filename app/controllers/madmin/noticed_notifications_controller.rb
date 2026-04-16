module Madmin
  class NoticedNotificationsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:event, :recipient)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = resources.includes(:recipient, :event)
      resources = resources.where(type: params[:type]) if params[:type].present?
      if params[:status] == "read"
        resources = resources.where.not(read_at: nil)
      elsif params[:status] == "unread"
        resources = resources.where(read_at: nil)
      end
      resources = resources.where("created_at >= ?", params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
      resources = resources.where("created_at <= ?", params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
      resources.reorder(sort_column => sort_direction)
    end
  end
end
