module Madmin
  class ChatsController < Madmin::ResourceController
    skip_before_action :set_record, only: :toggle_ai_chats

    def toggle_ai_chats
      setting = Setting.instance
      setting.update!(ai_chats_enabled: !setting.ai_chats_enabled?)
      redirect_to main_app.madmin_chats_path, notice: "AI Chats #{setting.ai_chats_enabled? ? 'enabled' : 'disabled'}"
    end

    private

    def scoped_resources
      resources = super.includes(:user, :model, :messages)

      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(created_at) = ?", date)
      end

      if params[:q].present?
        resources = resources.joins(:user).where("users.email LIKE ?", "%#{params[:q]}%")
      end

      resources
    end
  end
end
