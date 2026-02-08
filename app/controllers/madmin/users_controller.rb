module Madmin
  class UsersController < Madmin::ResourceController
    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:chats, memberships: :team)

      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(created_at) = ?", date)
      end

      case sort_column
      when "teams_count"
        resources
          .left_joins(:memberships)
          .group("users.id")
          .reorder(Arel.sql("COUNT(memberships.id) #{sort_direction}"))
      when "chats_count"
        resources
          .left_joins(:chats)
          .group("users.id")
          .reorder(Arel.sql("COUNT(chats.id) #{sort_direction}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
