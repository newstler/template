require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "has many conversation_messages ordered chronologically" do
    conversation = Conversation.create!(title: "Test")
    conversation.conversation_teams.create!(team: teams(:one))
    user = users(:one)
    ConversationParticipant.create!(conversation: conversation, user: user)

    old = conversation.conversation_messages.create!(user: user, content: "old", created_at: 1.day.ago, updated_at: 1.day.ago)
    new_msg = conversation.conversation_messages.create!(user: user, content: "new")

    assert_equal [ old, new_msg ], conversation.conversation_messages.chronologically.to_a
  end

  test "find_or_create_for matches exact team set" do
    team_a = teams(:one)
    team_b = teams(:two)

    conv = Conversation.find_or_create_for(teams: [ team_a, team_b ], subject: nil)

    assert_equal [ team_a, team_b ].map(&:id).sort, conv.teams.map(&:id).sort

    conv2 = Conversation.find_or_create_for(teams: [ team_a, team_b ], subject: nil)
    assert_equal conv.id, conv2.id

    conv3 = Conversation.find_or_create_for(teams: [ team_a ], subject: nil)
    assert_not_equal conv.id, conv3.id
  end

  test "team_for returns the team the user is a member of" do
    team_a = teams(:one)
    team_b = teams(:two)
    conv = Conversation.find_or_create_for(teams: [ team_a, team_b ], subject: nil)

    assert_equal team_a, conv.team_for(users(:one))
    assert_equal team_b, conv.team_for(users(:two))
  end
end
