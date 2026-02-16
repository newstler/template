# frozen_string_literal: true

module Articles
  class ShowArticleTool < ApplicationTool
    description "Get a specific article with full content"

    annotations(
      title: "Show Article",
      read_only_hint: true,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("Article ID")
      optional(:locale).filled(:string).description("Locale code for translated content (e.g., 'es')")
    end

    def call(id:, locale: nil)
      require_user!

      article = current_team.articles.find_by(id: id)
      return error_response("Article not found") unless article

      data = if locale
        Mobility.with_locale(locale) do
          serialize_article(article).merge(locale: locale)
        end
      else
        serialize_article(article)
      end

      success_response(data)
    end

    private

    def serialize_article(article)
      {
        id: article.id,
        title: article.title,
        body: article.body,
        author_id: article.user_id,
        created_at: format_timestamp(article.created_at),
        updated_at: format_timestamp(article.updated_at)
      }
    end
  end
end
