# frozen_string_literal: true

require "test_helper"
require "tools/mcp_test_helper"

module Chats
  class CreateChatToolTest < McpToolTestCase
    setup do
      @team = teams(:one)
      @user = users(:one)
      @model = ruby_llm_models(:gpt4)
    end

    test "requires team API key" do
      error = assert_raises(FastMcp::Tool::InvalidArgumentsError) do
        call_tool(Chats::CreateChatTool, model_id: @model.model_id)
      end
      assert_match(/x-api-key/, error.message)
    end

    test "creates a chat from a model name" do
      mock_mcp_request(team: @team, user: @user)

      assert_difference "@user.chats.count", 1 do
        result = call_tool(Chats::CreateChatTool, model_id: "gpt-4")

        assert result[:success]
        assert_equal "gpt-4", result[:data][:model_id]
        assert_equal "GPT-4", result[:data][:model_name]
      end
    end

    test "creates a chat from a registry id" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::CreateChatTool, model_id: @model.id)

      assert result[:success]
      assert_equal "gpt-4", result[:data][:model_id]
    end

    test "rejects a model whose provider has no credentials" do
      mock_mcp_request(team: @team, user: @user)
      ProviderCredential.where(provider: "anthropic").delete_all

      result = call_tool(Chats::CreateChatTool, model_id: "claude-3-opus-20240229")

      assert_not result[:success]
      assert_equal "invalid_model", result[:code]
    end

    test "returns error for invalid model" do
      mock_mcp_request(team: @team, user: @user)

      result = call_tool(Chats::CreateChatTool, model_id: "nonexistent")

      assert_not result[:success]
      assert_equal "invalid_model", result[:code]
    end
  end
end
