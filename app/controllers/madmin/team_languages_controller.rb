module Madmin
  class TeamLanguagesController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:team, :language)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = resources.includes(:team, :language)

      resources = resources.where(team_id: params[:team_id]) if params[:team_id].present?
      resources = resources.where(language_id: params[:language_id]) if params[:language_id].present?

      if params[:active].present?
        resources = resources.where(active: ActiveModel::Type::Boolean.new.cast(params[:active]))
      end

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "team_name"
        resources.joins(:team).reorder(Arel.sql("teams.name #{dir}"))
      when "language_name"
        resources.joins(:language).reorder(Arel.sql("languages.name #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
