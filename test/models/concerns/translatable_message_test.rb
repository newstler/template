require "test_helper"

class TranslatableMessageTest < ActiveSupport::TestCase
  test "ConversationMessage enqueues TranslateContentJob for each team target language" do
    conversation = conversations(:one)
    user = users(:one)
    # team_one has english (source) + spanish active.
    user.update_columns(locale: "en")

    message = nil
    assert_enqueued_jobs 1, only: TranslateContentJob do
      message = ConversationMessage.create!(conversation: conversation, user: user, content: "Hello")
    end
    job = ActiveJob::Base.queue_adapter.enqueued_jobs.find { |j| j[:job] == TranslateContentJob }
    assert_not_nil job
    assert_equal [ "ConversationMessage", message.id, "en", "es" ], job[:args]
  end

  test "ConversationMessage does not enqueue translations when only source language is active" do
    conversation = conversations(:one)
    user = users(:one)
    user.update_columns(locale: "en")
    # Disable spanish so only english remains.
    team_languages(:team_one_spanish).update!(active: false)

    assert_no_enqueued_jobs only: TranslateContentJob do
      ConversationMessage.create!(conversation: conversation, user: user, content: "Hi")
    end
  end
end
