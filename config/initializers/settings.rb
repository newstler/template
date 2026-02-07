Rails.application.config.after_initialize do
  Setting.reconfigure!
end
