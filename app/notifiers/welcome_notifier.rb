class WelcomeNotifier < ApplicationNotifier
  deliver_by :email do |config|
    config.mailer = "NotificationMailer"
    config.method = :welcome
    config.if     = -> {
      recipient.wants_notification?(kind: :welcome_notifier, channel: :email)
    }
  end

  notification_methods do
    def message
      I18n.t("notifiers.welcome_notifier.message", name: display_name)
    end

    def url
      Rails.application.routes.url_helpers.notifications_path
    end

    private

    def display_name
      record.respond_to?(:name) && record.name.present? ? record.name : record.email
    end
  end
end
