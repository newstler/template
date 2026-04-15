# frozen_string_literal: true

module Dashboards
  class ShowTeamDashboardTool < ApplicationTool
    description "Get team dashboard KPIs and time-series for the current team"

    annotations(
      title: "Show Team Dashboard",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:range).filled(:string).description("Time range: 7d, 30d (default), or 90d")
    end

    def call(range: "30d")
      require_user!

      parsed = parse_range(range)

      with_current_user do
        data = {
          team: {
            id: current_team.id,
            slug: current_team.slug,
            name: current_team.name
          },
          range: {
            key: normalize_range_key(range),
            from: parsed.begin.iso8601,
            to: parsed.end.iso8601
          },
          totals: {
            members: current_team.users.count,
            chats: current_team.chats.count,
            articles: current_team.articles.count
          },
          recent: {
            members: current_team.users.where(users: { created_at: parsed }).count,
            chats: current_team.chats.where(created_at: parsed).count,
            articles: current_team.articles.where(created_at: parsed).count
          },
          chats_timeline: current_team.chats
            .where(created_at: parsed)
            .group_by_day(:created_at, range: parsed)
            .count
            .transform_keys { |d| d.to_date.iso8601 }
        }

        success_response(data)
      end
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
  end
end
