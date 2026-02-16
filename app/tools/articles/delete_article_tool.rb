# frozen_string_literal: true

module Articles
  class DeleteArticleTool < ApplicationTool
    description "Delete an article"

    annotations(
      title: "Delete Article",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:id).filled(:string).description("Article ID")
    end

    def call(id:)
      require_user!

      article = current_team.articles.find_by(id: id)
      return error_response("Article not found") unless article

      article.destroy!

      success_response({ id: id }, message: "Article deleted")
    end
  end
end
