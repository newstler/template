class CreateTeamsForExistingUsers < ActiveRecord::Migration[8.2]
  def up
    User.find_each do |user|
      team_name = "#{user.name || user.email.split('@').first}'s Team"
      slug = team_name.parameterize

      # Ensure unique slug
      base_slug = slug
      counter = 1
      while Team.exists?(slug: slug)
        slug = "#{base_slug}-#{counter}"
        counter += 1
      end

      team = Team.create!(name: team_name, slug: slug)
      Membership.create!(user: user, team: team, role: "owner")

      # Assign all user's chats to their team
      Chat.where(user: user, team: nil).update_all(team_id: team.id)
    end
  end

  def down
    Membership.where(role: "owner").find_each do |membership|
      team = membership.team
      if team.memberships.count == 1
        team.chats.update_all(team_id: nil)
        team.destroy
      end
    end
  end
end
