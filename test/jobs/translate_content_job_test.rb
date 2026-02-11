require "test_helper"

class TranslateContentJobTest < ActiveSupport::TestCase
  MockResponse = Data.define(:content)
  include ActiveJob::TestHelper

  setup do
    @article = articles(:one)
  end

  test "skips if record not found" do
    assert_nothing_raised do
      TranslateContentJob.new.perform("Article", "nonexistent-id", "en", "es")
    end
  end

  test "translates content via RubyLLM" do
    mock_response = MockResponse.new(content: '{"title": "Hola Mundo", "body": "Cuerpo de prueba"}')
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

    original_chat = RubyLLM.method(:chat)
    RubyLLM.define_singleton_method(:chat) { |**_| mock_chat }

    TranslateContentJob.new.perform("Article", @article.id, "en", "es")

    Mobility.with_locale(:es) do
      @article.reload
      assert_equal "Hola Mundo", @article.title
      assert_equal "Cuerpo de prueba", @article.body
    end
  ensure
    RubyLLM.define_singleton_method(:chat, original_chat)
  end

  test "handles JSON wrapped in markdown code blocks" do
    mock_response = MockResponse.new(content: "```json\n{\"title\": \"Bonjour\", \"body\": \"Corps\"}\n```")
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

    original_chat = RubyLLM.method(:chat)
    RubyLLM.define_singleton_method(:chat) { |**_| mock_chat }

    TranslateContentJob.new.perform("Article", @article.id, "en", "fr")

    Mobility.with_locale(:fr) do
      @article.reload
      assert_equal "Bonjour", @article.title
      assert_equal "Corps", @article.body
    end
  ensure
    RubyLLM.define_singleton_method(:chat, original_chat)
  end

  test "handles invalid JSON response gracefully" do
    mock_response = MockResponse.new(content: "This is not JSON")
    mock_chat = Object.new
    mock_chat.define_singleton_method(:ask) { |_prompt| mock_response }

    original_chat = RubyLLM.method(:chat)
    RubyLLM.define_singleton_method(:chat) { |**_| mock_chat }

    assert_nothing_raised do
      TranslateContentJob.new.perform("Article", @article.id, "en", "es")
    end
  ensure
    RubyLLM.define_singleton_method(:chat, original_chat)
  end
end
