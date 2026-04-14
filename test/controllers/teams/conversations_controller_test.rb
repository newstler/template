require "test_helper"

class Teams::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    @user = users(:one)
    @conversation = conversations(:one)
    sign_in @user
  end

  test "GET show renders conversation for a participant" do
    get team_conversation_path(@team.slug, @conversation)
    assert_response :success
  end

  test "GET show is 404 for a team member who is not a participant" do
    # users(:three) is a member of team_one but not a participant of @conversation
    delete session_path
    sign_in users(:three)

    get team_conversation_path(@team.slug, @conversation)
    assert_response :not_found
  end

  test "GET show marks participant as read" do
    participant = ConversationParticipant.find_by!(conversation: @conversation, user: @user)
    participant.update!(last_read_at: nil)
    get team_conversation_path(@team.slug, @conversation)
    assert_not_nil participant.reload.last_read_at
  end
end
