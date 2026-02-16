# frozen_string_literal: true

module Articles
  class ListArticlesTool < ApplicationTool
    description "List articles for the current team"

    annotations(
      title: "List Articles",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      optional(:limit).filled(:integer).description("Max articles to return")
    end

    def call(limit: 20)
      require_user!

      articles = current_team.articles.includes(:user).recent.limit(limit)

      success_response(articles.map { |a| serialize_article(a) })
    end

    private

    def serialize_article(article)
      {
        id: article.id,
        title: article.title,
        body: article.body&.truncate(200),
        author: article.user.name,
        created_at: format_timestamp(article.created_at)
      }
    end
  end
end
