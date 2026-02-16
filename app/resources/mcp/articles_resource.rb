# frozen_string_literal: true

module Mcp
  class ArticlesResource < ApplicationResource
    uri "app:///articles"
    resource_name "Articles"
    description "Team's articles. Use list_articles tool for authenticated access."
    mime_type "application/json"

    def content
      to_json({
        message: "Use the 'list_articles' tool for authenticated article list",
        tool: "list_articles"
      })
    end
  end
end
