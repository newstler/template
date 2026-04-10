module Madmin
  class MembershipsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:team, :user, :invited_by)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = resources.includes(:team, :user)

      if params[:role].present?
        resources = resources.where(role: params[:role])
      end

      if params[:team_id].present?
        resources = resources.where(team_id: params[:team_id])
      end

      if params[:q].present?
        resources = resources.joins(:user, :team)
          .where("users.email LIKE :q OR users.name LIKE :q OR teams.name LIKE :q", q: "%#{params[:q]}%")
      end

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "user_name"
        resources
          .joins(:user)
          .reorder(Arel.sql("COALESCE(users.name, users.email) #{dir}"))
      when "team_name"
        resources
          .joins(:team)
          .reorder(Arel.sql("teams.name #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
