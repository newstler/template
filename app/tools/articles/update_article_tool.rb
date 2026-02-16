# frozen_string_literal: true

module Articles
  class UpdateArticleTool < ApplicationTool
    description "Update an existing article"

    annotations(
      title: "Update Article",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("Article ID")
      optional(:title).filled(:string).description("New title")
      optional(:body).filled(:string).description("New body")
    end

    def call(id:, title: nil, body: nil)
      require_user!

      article = current_team.articles.find_by(id: id)
      return error_response("Article not found") unless article

      updates = {}
      updates[:title] = title if title
      updates[:body] = body if body

      article.update!(updates) if updates.any?

      success_response(
        { id: article.id, title: article.title },
        message: "Article updated"
      )
    end
  end
end
