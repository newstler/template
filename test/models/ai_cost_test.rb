require "test_helper"

class AiCostTest < ActiveSupport::TestCase
  setup do
    @team = teams(:one)
    @user = users(:one)
  end

  test "records embedding cost with pricing from model record" do
    cost = AiCost.record!(
      cost_type: "embedding",
      model_id: models(:gpt4).model_id,
      input_tokens: 1_000_000,
      team: @team,
      user: @user,
    )

    assert cost.persisted?
    assert_equal "embedding", cost.cost_type
    assert_in_delta 30.0, cost.cost, 0.001
  end

  test "records translation cost" do
    cost = AiCost.record!(
      cost_type: "translation",
      model_id: models(:gpt4).model_id,
      input_tokens: 500,
      output_tokens: 200,
      team: @team,
      user: @user,
    )

    assert cost.persisted?
    assert_equal "translation", cost.cost_type
    assert cost.cost > 0
  end

  test "records chat cost" do
    cost = AiCost.record!(
      cost_type: "chat",
      model_id: models(:gpt4).model_id,
      input_tokens: 1000,
      output_tokens: 500,
      team: @team,
      user: @user,
    )

    assert cost.persisted?
    assert_equal "chat", cost.cost_type
  end

  test "validates cost_type inclusion" do
    assert_raises(ActiveRecord::RecordInvalid) do
      AiCost.record!(cost_type: "invalid", model_id: "test")
    end
  end

  test "team and user are optional" do
    cost = AiCost.record!(
      cost_type: "embedding",
      model_id: "text-embedding-3-small",
      input_tokens: 100,
    )

    assert cost.persisted?
    assert_nil cost.team
    assert_nil cost.user
  end

  test "scopes filter by cost type" do
    AiCost.record!(cost_type: "embedding", model_id: "test", input_tokens: 1)
    AiCost.record!(cost_type: "translation", model_id: "test", input_tokens: 1)
    AiCost.record!(cost_type: "chat", model_id: "test", input_tokens: 1)

    assert_equal 1, AiCost.embeddings.count
    assert_equal 1, AiCost.translations.count
  end
end
