# Mixed into RubyLLM::ActiveRecord::Model: which registry models this install can actually call.
module Enableable
  extend ActiveSupport::Concern

  included do
    scope :enabled, -> { listed.where(provider: ProviderCredential.configured_providers) }
    scope :embedding, -> { where("json_extract(modalities, '$.output') LIKE '%embedding%'") }
  end
end
