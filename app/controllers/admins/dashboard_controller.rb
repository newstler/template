module Admins
  class DashboardController < ApplicationController
    before_action :authenticate_admin!

    def index
      @metrics = {
        total_users: User.count,
        total_admins: Admin.count,
        total_chats: Chat.count,
        total_messages: Message.count,
        total_tokens: calculate_total_tokens,
        total_tool_calls: ToolCall.count,
        recent_chats: Chat.where("created_at >= ?", 7.days.ago).count,
        recent_messages: Message.where("created_at >= ?", 7.days.ago).count,
        recent_users: User.where("created_at >= ?", 7.days.ago).count,
        total_models: Model.count
      }

      @recent_chats = Chat.includes(:user).order(created_at: :desc).limit(5)
      @recent_users = User.order(created_at: :desc).limit(5)
    end

    private

    def calculate_total_tokens
      Message.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) + COALESCE(cached_tokens, 0) + COALESCE(cache_creation_tokens, 0)")
    end

    def authenticate_admin!
      admin = Admin.find_by(id: session[:admin_id]) if session[:admin_id]
      redirect_to new_admins_session_path unless admin
    end
  end
end
