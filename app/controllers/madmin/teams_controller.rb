module Madmin
  class TeamsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(memberships: :user, chats: [ :model, :messages ])
        .find_by!(slug: params[:id])
      @chat_costs = Chat.where(team: @record).joins(:ruby_llm_usages).group(:id).sum("ruby_llm_usages.total_cost")
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(memberships: :user, chats: []).with_usage_cost

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "owner_name"
        resources
          .left_joins(memberships: :user)
          .where(memberships: { role: "owner" })
          .or(resources.left_joins(memberships: :user).where(memberships: { id: nil }))
          .reorder(Arel.sql("users.name #{dir}"))
      when "members_count"
        resources
          .left_joins(:memberships)
          .group("teams.id")
          .reorder(Arel.sql("COUNT(memberships.id) #{dir}"))
      when "chats_count"
        resources
          .left_joins(:chats)
          .group("teams.id")
          .reorder(Arel.sql("COUNT(chats.id) #{dir}"))
      when "usage_cost"
        resources.reorder(Arel.sql("usage_cost #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
