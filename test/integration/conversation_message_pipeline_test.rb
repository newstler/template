require "test_helper"

class ConversationMessagePipelineTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @conversation = conversations(:one)
    @sender = users(:one)
    @sender.update_columns(locale: "en")
  end

  test "creating a message enqueues TranslateContentJob for every team language except the source" do
    # team_one has English (source) and Spanish active; only Spanish should be enqueued.
    message = nil
    assert_enqueued_jobs 1, only: TranslateContentJob do
      message = ConversationMessage.create!(
        conversation: @conversation,
        user: @sender,
        content: "Hello team"
      )
    end
    job = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j[:job] == TranslateContentJob }
    assert_not_nil job
    assert_equal [ "ConversationMessage", message.id, "en", "es" ], job[:args]
  end

  test "creating a message enqueues ModerateMessageJob" do
    assert_enqueued_with(job: ModerateMessageJob) do
      ConversationMessage.create!(
        conversation: @conversation,
        user: @sender,
        content: "Hello team"
      )
    end
  end

  test "regex moderation flags a message with an email address before delivery" do
    message = ConversationMessage.create!(
      conversation: @conversation,
      user: @sender,
      content: "Reach me at hello@example.com"
    )

    assert message.flagged_at.present?
    assert_match(/\Aregex:/, message.flag_reason)

    # Sender still sees it, recipient does not.
    recipient = users(:two)
    assert message.visible_to?(@sender)
    assert_not message.visible_to?(recipient)
  end

  test "regex-flagged messages do not enqueue the LLM moderation job" do
    assert_no_enqueued_jobs only: ModerateMessageJob do
      ConversationMessage.create!(
        conversation: @conversation,
        user: @sender,
        content: "email me at off@example.com"
      )
    end
  end
end
