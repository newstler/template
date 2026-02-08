module Madmin
  class TeamsController < Madmin::ResourceController
    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(memberships: :user, chats: [])

      case sort_column
      when "owner_name"
        resources
          .left_joins(memberships: :user)
          .where(memberships: { role: "owner" })
          .or(resources.left_joins(memberships: :user).where(memberships: { id: nil }))
          .reorder("users.name #{sort_direction}")
      when "members_count"
        resources
          .left_joins(:memberships)
          .group("teams.id")
          .reorder(Arel.sql("COUNT(memberships.id) #{sort_direction}"))
      when "chats_count"
        resources
          .left_joins(:chats)
          .group("teams.id")
          .reorder(Arel.sql("COUNT(chats.id) #{sort_direction}"))
      when "total_cost"
        resources
          .left_joins(:chats)
          .group("teams.id")
          .reorder(Arel.sql("COALESCE(SUM(chats.total_cost), 0) #{sort_direction}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
