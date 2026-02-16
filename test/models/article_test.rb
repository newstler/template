require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "validates presence of title" do
    article = Article.new(team: teams(:one), user: users(:one))
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end

  test "belongs to team" do
    article = articles(:one)
    assert_equal teams(:one), article.team
  end

  test "belongs to user" do
    article = articles(:one)
    assert_equal users(:one), article.user
  end

  test "recent scope orders by created_at desc" do
    articles = Article.recent
    assert_equal articles.pluck(:created_at), articles.pluck(:created_at).sort.reverse
  end

  test "includes Translatable" do
    assert Article.include?(Translatable)
  end

  test "translatable_attributes includes title and body" do
    assert_includes Article.translatable_attributes, "title"
    assert_includes Article.translatable_attributes, "body"
  end
end
