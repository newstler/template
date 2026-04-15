module Madmin
  class DashboardController < Madmin::ApplicationController
    def show
      @range = time_range_from(params[:range])

      @metrics = {
        total_users: User.count,
        total_admins: Admin.count,
        total_teams: Team.count,
        total_chats: Chat.count,
        total_messages: Message.count,
        total_tokens: calculate_total_tokens,
        total_cost: AiCost.sum(:cost),
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

      @top_teams = Team.joins(:chats)
        .select("teams.*, COUNT(DISTINCT chats.id) AS ai_chats_count, SUM(chats.messages_count) AS ai_messages_count, SUM(chats.total_cost) AS ai_total_cost")
        .group("teams.id")
        .order(Arel.sql("SUM(chats.total_cost) DESC"))
        .limit(5)

      @top_users = User.joins(:chats)
        .select("users.*, COUNT(DISTINCT chats.id) AS ai_chats_count, SUM(chats.messages_count) AS ai_messages_count, SUM(chats.total_cost) AS ai_total_cost")
        .group("users.id")
        .order(Arel.sql("SUM(chats.total_cost) DESC"))
        .limit(5)

      @cost_timeline = AiCost::COST_TYPES.map do |type|
        {
          name: type.titleize,
          data: AiCost.where(cost_type: type, created_at: @range)
                  .group_by_day(:created_at, range: @range)
                  .sum(:cost),
        }
      end

      @signup_timeline = User.where(created_at: @range)
        .group_by_day(:created_at, range: @range)
        .count
    end

    private

    def time_range_from(param)
      case param.to_s
      when "7d"  then 7.days.ago..Time.current
      when "90d" then 90.days.ago..Time.current
      else 30.days.ago..Time.current
      end
    end

    def calculate_total_tokens
      Message.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) + COALESCE(cached_tokens, 0) + COALESCE(cache_creation_tokens, 0)")
    end

    def calculate_subscription_revenue
      Rails.cache.fetch("admin_subscription_revenue", expires_in: 15.minutes) do
        fetch_stripe_mrr
      end.merge(total: calculate_total_revenue)
    end

    def calculate_total_revenue
      Rails.cache.fetch("admin:total_revenue", expires_in: 1.hour) do
        fetch_stripe_total_revenue
      end
    end

    def fetch_stripe_mrr
      return { mrr: 0, available: false } unless Setting.instance.stripe_secret_key.present?

      subs = Stripe::Subscription.list(status: "active", limit: 100)
      mrr = subs.data.sum do |s|
        s.items.data.sum do |item|
          amount = item.price.unit_amount.to_f
          item.price.recurring&.interval == "year" ? amount / 12.0 : amount
        end
      end / 100.0

      { mrr: mrr, available: true }
    rescue => e
      Rails.logger.warn("Failed to fetch Stripe MRR: #{e.message}")
      { mrr: 0, available: false }
    end

    # Iterates every paid invoice via Stripe's auto-paging iterator so
    # the admin total revenue metric reflects lifetime revenue, not
    # just the most recent 100 invoices.
    def fetch_stripe_total_revenue
      return 0 unless Setting.instance.stripe_secret_key.present?

      total = 0
      Stripe::Invoice.list(status: "paid", limit: 100).auto_paging_each do |invoice|
        total += invoice.amount_paid.to_i
      end
      total / 100.0
    rescue => e
      Rails.logger.warn("Failed to fetch Stripe total revenue: #{e.message}")
      0
    end
  end
end
