require "test_helper"

class ArticlesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @team = teams(:one)
    @article = articles(:one)
    sign_in(@user)
  end

  test "index lists articles" do
    get team_articles_path(@team)
    assert_response :success
  end

  test "show displays article" do
    get team_article_path(@team, @article)
    assert_response :success
  end

  test "new renders form" do
    get new_team_article_path(@team)
    assert_response :success
  end

  test "create saves article" do
    assert_difference "Article.count", 1 do
      post team_articles_path(@team), params: { article: { title: "New Article", body: "Content" } }
    end

    assert_redirected_to team_article_path(@team, Article.last)
  end

  test "edit renders form" do
    get edit_team_article_path(@team, @article)
    assert_response :success
  end

  test "update saves changes" do
    patch team_article_path(@team, @article), params: { article: { title: "Updated Title" } }
    assert_redirected_to team_article_path(@team, @article)
    assert_equal "Updated Title", @article.reload.title
  end

  test "destroy removes article" do
    assert_difference "Article.count", -1 do
      delete team_article_path(@team, @article)
    end

    assert_redirected_to team_articles_path(@team)
  end
end
