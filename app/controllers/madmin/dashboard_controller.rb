module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @metrics = {
        total_users: User.count,
        total_admins: Admin.count,
        total_chats: Chat.count,
        total_messages: Message.count,
        total_tokens: calculate_total_tokens,
        total_cost: Message.sum(:cost),
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

      # Batch load daily counts to avoid N+1
      user_counts = User.where(created_at: dates.first.all_day.first..dates.last.end_of_day)
                        .group("date(created_at)").count
      chat_counts = Chat.where(created_at: dates.first.all_day.first..dates.last.end_of_day)
                        .group("date(created_at)").count
      message_counts = Message.where(created_at: dates.first.all_day.first..dates.last.end_of_day)
                              .group("date(created_at)").count
      cost_sums = Message.where(created_at: dates.first.all_day.first..dates.last.end_of_day)
                         .group("date(created_at)").sum(:cost)

      {
        labels: dates.map { |d| d.strftime("%b %d") },
        users: dates.map { |d| user_counts[d.to_s] || 0 },
        chats: dates.map { |d| chat_counts[d.to_s] || 0 },
        messages: dates.map { |d| message_counts[d.to_s] || 0 },
        cost: dates.map { |d| (cost_sums[d.to_s] || 0).round(4) }
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
