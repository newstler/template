module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @metrics = {
        total_users: User.count,
        total_admins: Admin.count,
        total_chats: Chat.count,
        total_messages: Message.count,
        total_tokens: calculate_total_tokens,
        total_cost: calculate_total_cost,
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

    def calculate_total_cost
      Message.includes(:model).where.not(model_id: nil).sum do |msg|
        next 0 unless msg.model&.pricing.present?

        pricing = msg.model.pricing.dig("text_tokens", "standard") || {}
        input_rate = pricing["input_per_million"] || 0
        output_rate = pricing["output_per_million"] || 0
        cached_rate = pricing["cached_input_per_million"] || 0

        input_cost = (msg.input_tokens || 0) * input_rate / 1_000_000.0
        output_cost = (msg.output_tokens || 0) * output_rate / 1_000_000.0
        cached_cost = (msg.cached_tokens || 0) * cached_rate / 1_000_000.0

        input_cost + output_cost + cached_cost
      end
    end

    def build_activity_chart_data
      dates = (6.days.ago.to_date..Date.current).to_a

      {
        labels: dates.map { |d| d.strftime("%b %d") },
        users: dates.map { |d| User.where(created_at: d.all_day).count },
        chats: dates.map { |d| Chat.where(created_at: d.all_day).count },
        messages: dates.map { |d| Message.where(created_at: d.all_day).count },
        cost: dates.map { |d| calculate_daily_cost(d) }
      }
    end

    def calculate_daily_cost(date)
      Message.includes(:model).where(created_at: date.all_day).where.not(model_id: nil).sum do |msg|
        next 0 unless msg.model&.pricing.present?

        pricing = msg.model.pricing.dig("text_tokens", "standard") || {}
        input_rate = pricing["input_per_million"] || 0
        output_rate = pricing["output_per_million"] || 0
        cached_rate = pricing["cached_input_per_million"] || 0

        input_cost = (msg.input_tokens || 0) * input_rate / 1_000_000.0
        output_cost = (msg.output_tokens || 0) * output_rate / 1_000_000.0
        cached_cost = (msg.cached_tokens || 0) * cached_rate / 1_000_000.0

        input_cost + output_cost + cached_cost
      end.round(4)
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
