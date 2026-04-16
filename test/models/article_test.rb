require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "requires a title" do
    I18n.with_locale(:en) do
      article = Article.new(team: teams(:one), user: users(:one))
      assert_not article.valid?
      assert_includes article.errors[:title], "can't be blank"
    end
  end

  test "embedding_source_text includes translations" do
    article = articles(:one)

    # English-only source
    english_source = article.embedding_source_text
    assert_includes english_source, article.title
    assert_includes english_source, article.body

    # Add a Russian translation via Mobility
    article.skip_translation_callbacks = true
    Mobility.with_locale(:ru) do
      article.update!(title: "Русский заголовок", body: "Русский текст статьи")
    end
    article.skip_translation_callbacks = false

    multilingual_source = article.embedding_source_text
    assert_includes multilingual_source, article.title
    assert_includes multilingual_source, article.body
    assert_includes multilingual_source, "Русский заголовок"
    assert_includes multilingual_source, "Русский текст статьи"
  end
end
