RubyLLM.configure do |config|
  model = Setting.default_model
  config.default_model = model if model.present?
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, NameError
  # DB not ready yet (assets:precompile, first db:prepare)
end
