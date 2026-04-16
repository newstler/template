require "test_helper"

class Teams::Conversations::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    @user = users(:one)
    @conversation = conversations(:one)
    sign_in @user
  end

  test "POST creates a message with content" do
    assert_difference -> { @conversation.conversation_messages.count }, 1 do
      post team_conversation_messages_path(@team.slug, @conversation),
           params: { conversation_message: { content: "Hello world" } }
    end
    assert_redirected_to team_conversation_path(@team.slug, @conversation)
  end

  test "POST with attachments only" do
    file = fixture_file_upload("test.txt", "text/plain")
    assert_difference -> { @conversation.conversation_messages.count }, 1 do
      post team_conversation_messages_path(@team.slug, @conversation),
           params: { conversation_message: { attachments: [ file ] } }
    end
  end

  test "POST with neither content nor attachments returns unprocessable_entity" do
    post team_conversation_messages_path(@team.slug, @conversation),
         params: { conversation_message: { content: "" } }
    assert_response :unprocessable_entity
  end

  test "POST by non-participant team member is 404" do
    delete session_path
    sign_in users(:three)

    post team_conversation_messages_path(@team.slug, @conversation),
         params: { conversation_message: { content: "Hi" } }
    assert_response :not_found
  end
end
