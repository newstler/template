module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @metrics = {
        total_users: User.count,
        total_admins: Admin.count,
        total_teams: Team.count,
        total_chats: Chat.count,
        total_messages: Message.count,
        total_tokens: calculate_total_tokens,
        total_cost: Message.sum(:cost),
        total_tool_calls: ToolCall.count,
        recent_chats: Chat.where("created_at >= ?", 7.days.ago).count,
        recent_messages: Message.where("created_at >= ?", 7.days.ago).count,
        recent_users: User.where("created_at >= ?", 7.days.ago).count,
        recent_teams: Team.where("created_at >= ?", 7.days.ago).count,
        total_models: Model.enabled.count
      }

      @subscription_stats = {
        active: Team.where(subscription_status: "active").count,
        trialing: Team.where(subscription_status: "trialing").count,
        past_due: Team.where(subscription_status: "past_due").count,
        canceled: Team.where(subscription_status: "canceled").count,
        none: Team.where(subscription_status: [ nil, "" ]).count
      }

      @subscription_revenue = calculate_subscription_revenue

      @recent_chats = Chat.includes(:user, :model, :messages).order(created_at: :desc).limit(5)
      @recent_users = User.includes(:memberships).order(created_at: :desc).limit(5)
      @recent_teams = Team.includes(:memberships, :chats).order(created_at: :desc).limit(5)

      @activity_chart_data = build_activity_chart_data
    end

    private

    def calculate_total_tokens
      Message.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) + COALESCE(cached_tokens, 0) + COALESCE(cache_creation_tokens, 0)")
    end

    def calculate_subscription_revenue
      Rails.cache.fetch("admin_subscription_revenue", expires_in: 15.minutes) do
        fetch_stripe_revenue
      end
    end

    def fetch_stripe_revenue
      return { mrr: 0, total: 0, available: false } unless Setting.instance.stripe_secret_key.present?

      subs = Stripe::Subscription.list(status: "active", limit: 100)
      mrr = subs.data.sum do |s|
        s.items.data.sum do |item|
          amount = item.price.unit_amount.to_f
          item.price.recurring&.interval == "year" ? amount / 12.0 : amount
        end
      end / 100.0

      invoices = Stripe::Invoice.list(status: "paid", limit: 100)
      total = invoices.data.sum(&:amount_paid) / 100.0

      { mrr: mrr, total: total, available: true }
    rescue => e
      Rails.logger.warn("Failed to fetch Stripe revenue: #{e.message}")
      { mrr: 0, total: 0, available: false }
    end

    def build_activity_chart_data
      dates = (6.days.ago.to_date..Date.current).to_a

      cost_sums = Message.where(created_at: dates.first.all_day.first..dates.last.end_of_day)
                         .group("date(created_at)").sum(:cost)

      {
        labels: dates.map { |d| d.strftime("%b %d") },
        cost: dates.map { |d| (cost_sums[d.to_s] || 0).to_f }
      }
    end
  end
end
