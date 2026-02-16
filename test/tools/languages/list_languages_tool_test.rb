# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Languages
  class ListLanguagesToolTest < McpToolTestCase
    test "returns enabled languages without auth" do
      result = call_tool(Languages::ListLanguagesTool)

      assert result[:success]
      codes = result[:data].map { |l| l[:code] }
      assert_includes codes, "en"
      assert_includes codes, "es"
      assert_not_includes codes, "de"
    end
  end
end
