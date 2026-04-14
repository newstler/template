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
    click_on I18n.t("teams.conversations.composer.send")

    assert_selector "div", text: "Hello system test", wait: 5
  end

  test "new message from another user appears live via Turbo Stream" do
    sign_in_as @user
    visit team_conversation_path(@team.slug, @conversation)

    other = users(:two)
    ConversationParticipant.find_or_create_by!(conversation: @conversation, user: other)

    @conversation.conversation_messages.create!(user: other, content: "Live update")

    assert_selector "div", text: "Live update", wait: 5
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_on "Send magic link"
    token = user.generate_magic_link_token
    visit verify_magic_link_path(token: token)
  end
end
