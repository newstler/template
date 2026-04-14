require "test_helper"

class TranslatableMessageTest < ActiveSupport::TestCase
  class TestMessage < ConversationMessage
    include TranslatableMessage
  end

  test "enqueues TranslateMessageJob after create" do
    conversation = conversations(:one)
    user = users(:one)
    assert_enqueued_with(job: TranslateMessageJob) do
      TestMessage.create!(conversation: conversation, user: user, content: "Hello")
    end
  end
end
