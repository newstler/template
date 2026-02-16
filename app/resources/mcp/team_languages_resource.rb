# frozen_string_literal: true

module Mcp
  class TeamLanguagesResource < ApplicationResource
    uri "app:///team/languages"
    resource_name "Team Languages"
    description "Team's active languages. Use list_team_languages tool for authenticated access."
    mime_type "application/json"

    def content
      to_json({
        message: "Use the 'list_team_languages' tool for authenticated team language list",
        tool: "list_team_languages"
      })
    end
  end
end
