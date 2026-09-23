require "test_helper"

class AiCostTest < ActiveSupport::TestCase
  Response = Data.define(:tokens, :cost)

  setup do
    @team = teams(:one)
    @user = users(:one)
  end

  test "record_response! stores tokens and the cost RubyLLM computed" do
    cost = AiCost.record_response!(
      cost_type: "translation",
      model_id: "gpt-4",
      response: response(input: 500, output: 200, total: 0.027),
      team: @team,
      user: @user,
    )

    assert cost.persisted?
    assert_equal 500, cost.input_tokens
    assert_equal 200, cost.output_tokens
    assert_in_delta 0.027, cost.cost
  end

  test "record_response! stores zero when the model has no price" do
    cost = AiCost.record_response!(cost_type: "embedding", model_id: "unpriced", response: response(input: 1, total: nil))
    assert_equal 0, cost.cost
  end

  test "chat is no longer a cost type" do
    assert_not AiCost.new(cost_type: "chat", model_id: "gpt-4").valid?
  end

  test "team and user are optional" do
    cost = AiCost.record_response!(cost_type: "embedding", model_id: "text-embedding-3-small", response: response(input: 100, total: 0))

    assert cost.persisted?
    assert_nil cost.team
    assert_nil cost.user
  end

  test "scopes filter by cost type" do
    AiCost.record_response!(cost_type: "embedding", model_id: "test", response: response(input: 1, total: 0))
    AiCost.record_response!(cost_type: "translation", model_id: "test", response: response(input: 1, total: 0))
    AiCost.record_response!(cost_type: "moderation", model_id: "test", response: response(input: 1, total: 0))

    assert_equal 1, AiCost.embeddings.count
    assert_equal 1, AiCost.translations.count
    assert_equal 1, AiCost.moderations.count
  end

  private

  def response(input:, output: 0, total:)
    tokens = RubyLLM::Tokens.new(input: input, output: output)
    Response.new(tokens: tokens, cost: RubyLLM::Cost.from_h(total ? { total: total } : {}, tokens: tokens))
  end
end
