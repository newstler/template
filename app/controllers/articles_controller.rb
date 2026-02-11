class ArticlesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_article, only: [ :show, :edit, :update, :destroy ]

  def index
    @articles = current_team.articles.includes(:user).recent
  end

  def show
  end

  def new
    @article = current_team.articles.new
  end

  def create
    @article = current_team.articles.new(article_params)
    @article.user = current_user

    if @article.save
      redirect_to team_article_path(current_team, @article), notice: t("controllers.articles.create.notice")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @article.update(article_params)
      redirect_to team_article_path(current_team, @article), notice: t("controllers.articles.update.notice")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @article.destroy!
    redirect_to team_articles_path(current_team), notice: t("controllers.articles.destroy.notice")
  end

  private

  def set_article
    @article = current_team.articles.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body)
  end
end
