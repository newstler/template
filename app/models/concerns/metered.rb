# Mixed into RubyLLM::ActiveRecord::Model: per-model chat counts and spend for admin reporting.
# Usages record the model by name + provider, not by registry id.
module Metered
  extend ActiveSupport::Concern

  included do
    scope :with_usage_cost, -> {
      select(
        "ruby_llm_models.*",
        "(SELECT COUNT(*) FROM chats WHERE chats.ruby_llm_model_id = ruby_llm_models.id) AS chats_count",
        "(SELECT COALESCE(SUM(u.total_cost), 0) FROM ruby_llm_usages u " \
        "WHERE u.provider = ruby_llm_models.provider AND u.model = ruby_llm_models.model_id) AS usage_cost"
      )
    }
  end
end
