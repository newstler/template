Rails.application.config.to_prepare do
  [ Enableable, Metered ].each do |concern|
    RubyLLM::ActiveRecord::Model.include(concern) unless RubyLLM::ActiveRecord::Model < concern
  end
end
