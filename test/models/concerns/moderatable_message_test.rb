require "test_helper"

class ModeratableMessageTest < ActiveSupport::TestCase
  class TestMessage < ConversationMessage
    include ModeratableMessage
  end

  test "enqueues ModerateMessageJob after create" do
    conversation = conversations(:one)
    user = users(:one)
    assert_enqueued_with(job: ModerateMessageJob) do
      TestMessage.create!(conversation: conversation, user: user, content: "Hi")
    end
  end
end
