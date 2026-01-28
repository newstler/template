class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.credentials.dig(:mailer, :from_address) || "noreply@example.com" }
  layout "mailer"
end
