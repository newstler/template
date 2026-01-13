module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
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

      @activity_chart_data = build_activity_chart_data
      @message_role_data = build_message_role_data
    end

    private

    def calculate_total_tokens
      Message.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) + COALESCE(cached_tokens, 0) + COALESCE(cache_creation_tokens, 0)")
    end

    def build_activity_chart_data
      dates = (6.days.ago.to_date..Date.current).to_a

      {
        labels: dates.map { |d| d.strftime("%b %d") },
        users: dates.map { |d| User.where(created_at: d.all_day).count },
        chats: dates.map { |d| Chat.where(created_at: d.all_day).count },
        messages: dates.map { |d| Message.where(created_at: d.all_day).count }
      }
    end

    def build_message_role_data
      roles = Message.group(:role).count
      {
        labels: roles.keys.map(&:titleize),
        values: roles.values
      }
    end
  end
end
