class NotificationMailer < ApplicationMailer
  def welcome
    @notification = params[:notification]
    @user         = @notification.recipient
    mail(to: @user.email, subject: I18n.t("notifiers.welcome_notifier.email.subject"))
  end
end
