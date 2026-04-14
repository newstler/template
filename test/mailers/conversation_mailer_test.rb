require "test_helper"

class ConversationMailerTest < ActionMailer::TestCase
  setup do
    @conversation = conversations(:one)
    @recipient = users(:one)
    @message = conversation_messages(:first)
  end

  test "new_message renders" do
    mail = ConversationMailer.with(message: @message, recipient: @recipient).new_message
    assert_equal [ @recipient.email ], mail.to
    assert_match @message.content, mail.body.encoded
  end

  test "messages_digest renders with up to 3 most recent messages per conversation" do
    # Create 4 messages so the digest shows top 3
    4.times { |i| @conversation.conversation_messages.create!(user: @recipient, content: "Msg #{i}") }
    mail = ConversationMailer.with(recipient: @recipient, conversations: [ @conversation ]).messages_digest
    assert_match "Msg 3", mail.body.encoded
  end
end
