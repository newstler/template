# frozen_string_literal: true

module Mcp
  class AvailableLanguagesResource < ApplicationResource
    uri "app:///languages"
    resource_name "Available Languages"
    description "List of all enabled languages available for translation"
    mime_type "application/json"

    def content
      languages = Language.enabled.by_name

      to_json({
        languages_count: languages.count,
        languages: languages.map { |l|
          {
            id: l.id,
            code: l.code,
            name: l.name,
            native_name: l.native_name
          }
        }
      })
    end
  end
end
