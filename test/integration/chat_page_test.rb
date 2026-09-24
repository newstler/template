require "test_helper"

class ChatPageTest < ActionDispatch::IntegrationTest
  test "shows a chat's messages with their tool calls" do
    sign_in users(:one)

    get team_chat_path(teams(:one).slug, chats(:one))

    assert_response :success
    assert_includes response.body, "I&#39;m doing well"
    assert_includes response.body, "search"
    assert_includes response.body, "weather in Paris"
  end
end
