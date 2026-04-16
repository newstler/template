require "test_helper"

module Madmin
  class ConversationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      sign_in_admin @admin
    end

    test "admin can list conversations" do
      get madmin_conversations_path
      assert_response :success
    end

    test "admin can view a conversation" do
      conversation = conversations(:one)
      get madmin_conversation_path(conversation)
      assert_response :success
    end

    test "admin can list conversation messages" do
      get madmin_conversation_messages_path
      assert_response :success
    end

    test "admin can view a conversation message" do
      message = conversation_messages(:first)
      get madmin_conversation_message_path(message)
      assert_response :success
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { session: { email: admin.email } }
      token = admin.generate_magic_link_token
      get admins_verify_magic_link_path(token: token)
    end
  end
end
