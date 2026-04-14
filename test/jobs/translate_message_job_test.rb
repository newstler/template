require "test_helper"

class TranslateMessageJobTest < ActiveJob::TestCase
  test "no-op when content is blank" do
    message = conversation_messages(:first)
    message.update_columns(content: nil)
    TranslateMessageJob.perform_now(message.id)
    assert_equal({}, message.reload.body_translations)
  end

  test "no-op when no other participants with a locale exist" do
    message = conversation_messages(:first)
    # Clear locales on all other participants so target_locales is empty.
    message.conversation.participants.where.not(id: message.user_id).each do |u|
      u.update_columns(locale: nil)
    end
    TranslateMessageJob.perform_now(message.id)
    assert_equal({}, message.reload.body_translations)
  end

  test "no-op when message does not exist" do
    # Should just return without raising
    assert_nothing_raised do
      TranslateMessageJob.perform_now("00000000-0000-0000-0000-000000000000")
    end
  end
end
