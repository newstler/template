require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @team = teams(:one)
    @conversation = conversations(:one)
    @user = users(:one)
  end

  test "a participant can view and post a message" do
    sign_in_as @user
    visit team_conversation_path(@team.slug, @conversation)

    assert_selector "#conversation_messages"

    fill_in "conversation_message[content]", with: "Hello system test"
    find("#conversation_message_form button[type='submit']").click

    assert_selector "div", text: "Hello system test", wait: 5
  end

  test "new message from another user appears live via Turbo Stream" do
    sign_in_as @user
    visit team_conversation_path(@team.slug, @conversation)

    other = users(:two)
    ConversationParticipant.find_or_create_by!(conversation: @conversation, user: other)

    message = @conversation.conversation_messages.create!(user: other, content: "Live update")
    message.broadcast_to_other_participants

    assert_selector "div", text: "Live update", wait: 5
  end
end
