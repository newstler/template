require "test_helper"

class ModelRegistryPagesTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    sign_in users(:one)
  end

  test "models page lists enabled registry models with their prices" do
    get team_models_path(@team.slug)

    assert_response :success
    assert_includes response.body, "GPT-4"
    assert_includes response.body, "$30.00 / $60.00"
  end

  test "model page shows a registry model" do
    get team_model_path(@team.slug, ruby_llm_models(:gpt4))

    assert_response :success
    assert_includes response.body, "gpt-4"
  end

  test "new chat offers enabled registry models" do
    get new_team_chat_path(@team.slug)

    assert_response :success
    assert_includes response.body, %(value="claude-3-opus-20240229")
  end

  test "refreshing the registry keeps the new chat page working" do
    sign_in_admin admins(:one)
    original = RubyLLM.method(:models)
    RubyLLM.define_singleton_method(:models) { Data.define { def refresh = nil }.new }
    post team_models_refresh_path(@team.slug)
    RubyLLM.define_singleton_method(:models, original)

    assert_redirected_to team_models_path(@team.slug)
    get new_team_chat_path(@team.slug)
    assert_response :success
  ensure
    RubyLLM.define_singleton_method(:models, original) if original
  end

  private

  def sign_in_admin(admin)
    post admins_session_path, params: { session: { email: admin.email } }
    get admins_verify_magic_link_path(token: admin.generate_magic_link_token)
  end
end
