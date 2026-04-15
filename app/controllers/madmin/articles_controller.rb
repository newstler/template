module Madmin
  class ArticlesController < Madmin::ResourceController
    skip_before_action :set_record, only: :toggle_articles
    rescue_from Embeddable::EmbeddingDimensionMismatch, with: :handle_dimension_mismatch

    def toggle_articles
      setting = Setting.instance
      setting.update!(articles_enabled: !setting.articles_enabled?)
      redirect_to main_app.madmin_articles_path, notice: "Articles #{setting.articles_enabled? ? 'enabled' : 'disabled'}"
    end

    private

    def handle_dimension_mismatch(exception)
      redirect_to main_app.madmin_articles_path, alert: exception.message
    end

    def set_record
      @record = resource.model
        .includes(:team, :user)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = if search_term.present?
        resources.hybrid_search(search_term, limit: 100, max_distance: Setting.max_similarity_distance)
      else
        resources
      end
      resources = resources.includes(:team, :user)

      if params[:team_id].present?
        resources = resources.where(team_id: params[:team_id])
      end

      return resources if search_term.present? && params[:sort].blank?

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "team_name"
        resources
          .joins(:team)
          .reorder(Arel.sql("teams.name #{dir}"))
      when "author_name"
        resources
          .joins(:user)
          .reorder(Arel.sql("users.name #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
