require "test_helper"

class ModeratableMessageTest < ActiveSupport::TestCase
  setup do
    @conversation = conversations(:one)
    @user = users(:one)
  end

  test "ConversationMessage enqueues ModerateMessageJob after create" do
    assert_enqueued_with(job: ModerateMessageJob) do
      ConversationMessage.create!(conversation: @conversation, user: @user, content: "Hi there")
    end
  end

  test "regex gate flags messages with emails" do
    message = ConversationMessage.create!(conversation: @conversation, user: @user, content: "Email me at foo@bar.com")
    assert message.flagged_at.present?
    assert_match(/\Aregex:/, message.flag_reason)
  end

  test "regex gate does not flag when moderation is disabled" do
    Setting.instance.update!(conversation_moderation_enabled: false)
    message = ConversationMessage.create!(conversation: @conversation, user: @user, content: "Email me at foo@bar.com")
    assert_nil message.flagged_at
  end

  test "LLM job is not enqueued when moderation is disabled" do
    Setting.instance.update!(conversation_moderation_enabled: false)
    assert_no_enqueued_jobs(only: ModerateMessageJob) do
      ConversationMessage.create!(conversation: @conversation, user: @user, content: "Hi there")
    end
  end
end
