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
end
