require "test_helper"

class BackfillTranslationsJobTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "skips if team not found" do
    assert_nothing_raised do
      BackfillTranslationsJob.new.perform("nonexistent-id", "es")
    end
  end

  test "enqueues TranslateContentJob for existing records" do
    team = teams(:one)
    # articles fixture already has records for team one

    assert_enqueued_with(job: TranslateContentJob) do
      BackfillTranslationsJob.new.perform(team.id, "es")
    end
  end
end
