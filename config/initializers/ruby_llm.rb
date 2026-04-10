RubyLLM.configure do |config|
  model = Setting.default_model
  config.default_model = model if model.present?
  config.use_new_acts_as = true
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NameError
  config.use_new_acts_as = true
end
