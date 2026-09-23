Rails.application.config.to_prepare do
  RubyLLM::ActiveRecord::Model.include(Enableable) unless RubyLLM::ActiveRecord::Model < Enableable
end
