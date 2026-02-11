require "test_helper"

class TranslatableTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @team = teams(:one)
    @user = users(:one)
  end

  test "translatable_attributes tracks declared attributes" do
    assert_includes Article.translatable_attributes, "title"
    assert_includes Article.translatable_attributes, "body"
  end

  test "queue_translations enqueues jobs on create" do
    assert_enqueued_with(job: TranslateContentJob) do
      Article.create!(team: @team, user: @user, title: "Hello World", body: "Test body")
    end
  end

  test "queue_translations skips when skip_translation_callbacks is set" do
    article = articles(:one)

    article.skip_translation_callbacks = true
    assert_no_enqueued_jobs(only: TranslateContentJob) do
      article.update!(title: "Updated")
    end
  end

  test "queue_translations skips when no translatable attributes changed" do
    article = articles(:one)
    assert_no_enqueued_jobs(only: TranslateContentJob) do
      article.touch
    end
  end
end
