# frozen_string_literal: true

module Articles
  class CreateArticleTool < ApplicationTool
    description "Create a new article"

    annotations(
      title: "Create Article",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:title).filled(:string).description("Article title")
      optional(:body).filled(:string).description("Article body")
    end

    def call(title:, body: nil)
      with_current_user do
        article = current_team.articles.create!(
          user: current_user,
          title: title,
          body: body,
        )

        success_response(
          { id: article.id, title: article.title },
          message: "Article created"
        )
      end
    end
  end
end
