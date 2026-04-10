module Madmin
  class ArticlesController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:team, :user)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:team, :user)

      if params[:team_id].present?
        resources = resources.where(team_id: params[:team_id])
      end

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
