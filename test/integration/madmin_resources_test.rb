require "test_helper"

# Smoke test for every Madmin resource: every index and every show must render
# without 500s. Guards against breakage in custom views/controllers.
class MadminResourcesTest < ActionDispatch::IntegrationTest
  setup do
    @admin = admins(:one)
    sign_in_admin @admin
  end

  test "admin dashboard renders" do
    get madmin_root_path
    assert_response :success
  end

  # === Accounts ===

  test "users index and show" do
    get madmin_users_path
    assert_response :success
    get madmin_user_path(users(:one))
    assert_response :success
  end

  test "teams index and show" do
    get madmin_teams_path
    assert_response :success
    get madmin_team_path(teams(:one))
    assert_response :success
  end

  test "memberships index and show" do
    get madmin_memberships_path
    assert_response :success
    get madmin_membership_path(memberships(:user_one_team_one))
    assert_response :success
  end

  test "admins index and show" do
    get madmin_admins_path
    assert_response :success
    get madmin_admin_path(admins(:one))
    assert_response :success
  end

  # === Content ===

  test "articles index and show" do
    get madmin_articles_path
    assert_response :success
    get madmin_article_path(articles(:one))
    assert_response :success
  end

  test "chats index and show" do
    get madmin_chats_path
    assert_response :success
    get madmin_chat_path(chats(:one))
    assert_response :success
  end

  test "messages index and show" do
    get madmin_messages_path
    assert_response :success
    get madmin_message_path(messages(:user_message))
    assert_response :success
    get madmin_message_path(messages(:assistant_message))
    assert_response :success
    assert_includes response.body, "$0.0012"
    assert_includes response.body, "search"
  end

  test "chat show survives an unpriced usage attempt" do
    chats(:one).ruby_llm_usages.create!(operation: "chat", provider: "openai", model: "gpt-4", status: "failed")
    get madmin_chat_path(chats(:one))
    assert_response :success
    assert_includes response.body, "$0.0012"
  end

  test "chats index orders rows by usage cost" do
    chats(:two).ruby_llm_usages.create!(operation: "chat", provider: "anthropic", model: "claude-3-opus-20240229", status: "succeeded", total_cost: 5)
    get madmin_chats_path, params: { sort: "usage_cost", direction: "desc" }
    assert_response :success
    assert_operator response.body.index("$5.0000"), :<, response.body.index("$0.0012")
  end

  test "chats index loads messages in one query regardless of rows" do
    3.times { Chat.create!(user: users(:one), team: teams(:one), model: "gpt-4").messages.create!(role: "user", content: "hi") }

    assert_equal 1, count_queries(/SELECT "messages"\.\* FROM "messages"/) { get madmin_chats_path }
  end

  test "chat show renders tokens and cost from usages" do
    get madmin_chat_path(chats(:one))
    assert_response :success
    assert_includes response.body, "$0.0012"
  end

  %w[chats users teams models].each do |resource|
    test "#{resource} index sorts by usage cost" do
      get "/madmin/#{resource}", params: { sort: "usage_cost", direction: "desc" }
      assert_response :success
    end
  end

  test "models index sorts by chats count" do
    get "/madmin/models", params: { sort: "chats_count", direction: "desc" }
    assert_response :success
  end

  test "tool_calls index and show" do
    get madmin_tool_calls_path
    assert_response :success
    get madmin_tool_call_path(ruby_llm_tool_calls(:search_call))
    assert_response :success
  end

  test "conversations index and show" do
    get madmin_conversations_path
    assert_response :success
    get madmin_conversation_path(conversations(:one))
    assert_response :success
  end

  test "conversation_messages index and show" do
    get madmin_conversation_messages_path
    assert_response :success
    get madmin_conversation_message_path(conversation_messages(:first))
    assert_response :success
  end

  test "conversation_participants index and show" do
    get madmin_conversation_participants_path
    assert_response :success
    get madmin_conversation_participant_path(conversation_participants(:one_one))
    assert_response :success
  end

  # === AI ===

  test "models index and show" do
    get madmin_models_path
    assert_response :success
    get madmin_model_path(ruby_llm_models(:gpt4))
    assert_response :success
  end

  # === Notifications ===

  test "noticed_events index" do
    get madmin_noticed_events_path
    assert_response :success
  end

  test "noticed_notifications index" do
    get madmin_noticed_notifications_path
    assert_response :success
  end

  # === Config ===

  test "languages index and show" do
    get madmin_languages_path
    assert_response :success
    get madmin_language_path(languages(:english))
    assert_response :success
  end

  test "team_languages index and show" do
    get madmin_team_languages_path
    assert_response :success
    get madmin_team_language_path(team_languages(:team_one_english))
    assert_response :success
  end

  test "settings edit renders" do
    get madmin_settings_path
    assert_response :success
  end

  test "ai_models show renders" do
    get madmin_ai_models_path
    assert_response :success
  end

  test "providers index renders" do
    get madmin_providers_path
    assert_response :success
  end

  test "prices show renders" do
    get madmin_prices_path
    assert_response :success
  end

  test "mail show renders" do
    get madmin_mail_path
    assert_response :success
  end

  private

  def count_queries(matching, &block)
    count = 0
    counter = ->(*, payload) { count += 1 if payload[:sql].match?(matching) && !payload[:cached] }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end

  def sign_in_admin(admin)
    post admins_session_path, params: { session: { email: admin.email } }
    token = admin.generate_magic_link_token
    get admins_verify_magic_link_path(token: token)
  end
end
