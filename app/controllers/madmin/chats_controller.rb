module Madmin
  class ChatsController < Madmin::ResourceController
    skip_before_action :set_record, only: :toggle_ai_chats

    def toggle_ai_chats
      setting = Setting.instance
      setting.update!(ai_chats_enabled: !setting.ai_chats_enabled?)
      redirect_to main_app.madmin_chats_path, notice: t("controllers.madmin.chats.toggle_ai_chats.#{setting.ai_chats_enabled? ? 'enabled' : 'disabled'}")
    end

    private

    def set_record
      @record = resource.model.includes(:user, :model, :ruby_llm_usages, messages: [ :ruby_llm_usages, :ruby_llm_tool_calls ]).find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:user, :model).with_usage_cost

      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(chats.created_at) = ?", date)
      end

      if params[:q].present?
        resources = resources.joins(:user).where("users.email LIKE ?", "%#{params[:q]}%")
      end

      return resources if sort_column.blank?

      if sort_column == "usage_cost"
        resources.reorder(Arel.sql("usage_cost #{sort_direction == 'asc' ? 'ASC' : 'DESC'}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
