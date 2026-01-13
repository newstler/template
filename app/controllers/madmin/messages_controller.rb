module Madmin
  class MessagesController < Madmin::ResourceController
    def scoped_resources
      resources = super.includes(:chat, :model, :tool_calls)

      # Role filter
      resources = resources.where(role: params[:role]) if params[:role].present?

      # Date filter
      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(created_at) = ?", date)
      end

      resources
    end
  end
end
