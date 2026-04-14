require "test_helper"

class ModerateMessageJobTest < ActiveJob::TestCase
  setup { @message = conversation_messages(:first) }

  test "regex flags an email" do
    @message.update!(content: "reach me at john@example.com")
    ModerateMessageJob.perform_now(@message.id)
    assert @message.reload.flagged_at.present?
  end

  test "regex flags a phone number" do
    @message.update!(content: "call me +7 925 123 45 67")
    ModerateMessageJob.perform_now(@message.id)
    assert @message.reload.flagged_at.present?
  end

  test "regex flags an @handle" do
    @message.update!(content: "find me @telegram_user")
    ModerateMessageJob.perform_now(@message.id)
    assert @message.reload.flagged_at.present?
  end

  test "clean content is not flagged" do
    @message.update!(content: "Looking forward to working together")
    ModerateMessageJob.perform_now(@message.id)
    assert_nil @message.reload.flagged_at
  end

  test "no-op for missing message id" do
    assert_nothing_raised do
      ModerateMessageJob.perform_now("00000000-0000-0000-0000-000000000000")
    end
  end
end
