require "test_helper"

class ArticleTest < ActiveSupport::TestCase
  test "requires a title" do
    article = Article.new(team: teams(:one), user: users(:one))
    assert_not article.valid?
    assert_includes article.errors[:title], "can't be blank"
  end
end
