require "test_helper"

class ModeratableMessageTest < ActiveSupport::TestCase
  test "ConversationMessage enqueues ModerateMessageJob after create" do
    conversation = conversations(:one)
    user = users(:one)
    assert_enqueued_with(job: ModerateMessageJob) do
      ConversationMessage.create!(conversation: conversation, user: user, content: "Hi there")
    end
  end
end
