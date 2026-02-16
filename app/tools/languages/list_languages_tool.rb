# frozen_string_literal: true

module Languages
  class ListLanguagesTool < ApplicationTool
    description "List all enabled languages available for translation"

    annotations(
      title: "List Languages",
      read_only_hint: true,
      open_world_hint: false
    )

    def call
      languages = Language.enabled.by_name

      success_response(languages.map { |l|
        {
          id: l.id,
          code: l.code,
          name: l.name,
          native_name: l.native_name
        }
      })
    end
  end
end
