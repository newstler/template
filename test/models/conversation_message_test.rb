require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(title: "Test")
    @conversation.conversation_teams.create!(team: teams(:one))
    @user = users(:one)
    ConversationParticipant.create!(conversation: @conversation, user: @user)
  end

  test "is valid with content only" do
    message = @conversation.conversation_messages.new(user: @user, content: "Hello")
    assert message.valid?
  end

  test "is valid with an attachment and no content" do
    message = @conversation.conversation_messages.new(user: @user)
    message.attachments.attach(
      io: File.open(Rails.root.join("test/fixtures/files/test.txt")),
      filename: "test.txt",
      content_type: "text/plain"
    )
    assert message.valid?
  end

  test "is invalid with neither content nor attachments" do
    message = @conversation.conversation_messages.new(user: @user)
    assert_not message.valid?
    assert message.errors.any?
  end

  test "touches the conversation on create" do
    original = 1.day.ago
    @conversation.update_column(:updated_at, original)
    @conversation.conversation_messages.create!(user: @user, content: "Hi")
    assert @conversation.reload.updated_at > original
  end

  test "body_for returns the user's locale translation or falls back to content" do
    message = @conversation.conversation_messages.create!(
      user: @user,
      content: "Hi",
      body_translations: { "es" => "Hola" }
    )

    es_user = users(:one)
    es_user.update!(locale: "es")
    assert_equal "Hola", message.body_for(es_user)

    en_user = users(:two)
    en_user.update!(locale: "en")
    assert_equal "Hi", message.body_for(en_user)
  end
end
