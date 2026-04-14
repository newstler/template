require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "belongs to a team" do
    conversation = Conversation.new(team: teams(:one))
    assert_equal teams(:one), conversation.team
  end

  test "has a polymorphic subject (optional)" do
    conversation = Conversation.new(team: teams(:one))
    assert_nil conversation.subject
    assert conversation.valid?
  end

  test "has a title" do
    conversation = Conversation.new(team: teams(:one), title: "Planning")
    assert_equal "Planning", conversation.title
  end
end
