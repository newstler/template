# frozen_string_literal: true

module Dashboards
  class ShowAdminDashboardTool < ApplicationTool
    admin_only!

    description "Get platform-wide admin dashboard aggregates (admin-only)"

    annotations(
      title: "Show Admin Dashboard",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:range).filled(:string).description("Time range: 7d, 30d (default), or 90d")
    end

    def call(range: "30d")
      require_admin!

      parsed = parse_range(range)

      data = {
        range: {
          key: normalize_range_key(range),
          from: parsed.begin.iso8601,
          to: parsed.end.iso8601
        },
        totals: {
          users: User.count,
          admins: Admin.count,
          teams: Team.count,
          chats: Chat.count,
          messages: Message.count,
          tool_calls: ToolCall.count,
          tokens: total_tokens,
          ai_cost: Message.sum(:cost).to_f
        },
        recent: {
          users: User.where(created_at: parsed).count,
          teams: Team.where(created_at: parsed).count,
          chats: Chat.where(created_at: parsed).count,
          messages: Message.where(created_at: parsed).count
        },
        subscriptions: subscription_stats,
        cost_timeline: Message.where(created_at: parsed)
          .group_by_day(:created_at, range: parsed)
          .sum(:cost)
          .transform_keys { |d| d.to_date.iso8601 }
          .transform_values(&:to_f),
        signup_timeline: User.where(created_at: parsed)
          .group_by_day(:created_at, range: parsed)
          .count
          .transform_keys { |d| d.to_date.iso8601 },
        top_teams: top_teams,
        top_users: top_users
      }

      success_response(data)
    end

    private

    def parse_range(range)
      case range.to_s
      when "7d"  then 7.days.ago..Time.current
      when "90d" then 90.days.ago..Time.current
      else 30.days.ago..Time.current
      end
    end

    def normalize_range_key(range)
      %w[7d 30d 90d].include?(range.to_s) ? range.to_s : "30d"
    end

    def total_tokens
      Message.sum("COALESCE(input_tokens, 0) + COALESCE(output_tokens, 0) + COALESCE(cached_tokens, 0) + COALESCE(cache_creation_tokens, 0)").to_i
    end

    def subscription_stats
      {
        active: Team.where(subscription_status: "active").count,
        trialing: Team.where(subscription_status: "trialing").count,
        past_due: Team.where(subscription_status: "past_due").count,
        canceled: Team.where(subscription_status: "canceled").count,
        none: Team.where(subscription_status: [ nil, "" ]).count
      }
    end

    def top_teams
      Team.joins(:chats)
        .select("teams.id, teams.slug, teams.name, COUNT(DISTINCT chats.id) AS ai_chats_count, SUM(chats.total_cost) AS ai_total_cost")
        .group("teams.id")
        .order(Arel.sql("SUM(chats.total_cost) DESC"))
        .limit(5)
        .map do |t|
          {
            id: t.id,
            slug: t.slug,
            name: t.name,
            chats_count: t.ai_chats_count.to_i,
            total_cost: t.ai_total_cost.to_f
          }
        end
    end

    def top_users
      User.joins(:chats)
        .select("users.id, users.email, users.name, COUNT(DISTINCT chats.id) AS ai_chats_count, SUM(chats.total_cost) AS ai_total_cost")
        .group("users.id")
        .order(Arel.sql("SUM(chats.total_cost) DESC"))
        .limit(5)
        .map do |u|
          {
            id: u.id,
            email: u.email,
            name: u.name,
            chats_count: u.ai_chats_count.to_i,
            total_cost: u.ai_total_cost.to_f
          }
        end
    end
  end
end
