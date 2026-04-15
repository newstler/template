class HomeController < ApplicationController
  include DashboardHelper

  before_action :authenticate_user!

  def index
    @user = current_user
    @range = time_range_from(params[:range])

    @total_users    = current_team.users.count
    @total_chats    = current_team.chats.count
    @total_articles = current_team.articles.count

    @recent_users = cached_dashboard(:recent_users) do
      current_team.users.where(users: { created_at: @range }).count
    end

    @recent_chats = cached_dashboard(:recent_chats) do
      current_team.chats.where(created_at: @range).count
    end

    @recent_articles = cached_dashboard(:recent_articles) do
      current_team.articles.where(created_at: @range).count
    end

    @chats_timeline = cached_dashboard(:chats_timeline) do
      current_team.chats
        .where(created_at: @range)
        .group_by_day(:created_at, range: @range)
        .count
    end

    @attention_items = build_attention_items
  end

  private

  def build_attention_items
    items = []

    if Setting.stripe_configured? && !current_team.subscription_active?
      items << {
        severity: :info,
        label: t("home.index.attention.no_subscription"),
        path: team_pricing_path(current_team.slug)
      }
    end

    if current_team.languages.count <= 1
      items << {
        severity: :info,
        label: t("home.index.attention.add_language"),
        path: team_languages_path(current_team.slug)
      }
    end

    items
  end
end
