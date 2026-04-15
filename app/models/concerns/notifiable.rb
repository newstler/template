module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  end

  def wants_notification?(kind:, channel:)
    return true unless respond_to?(:notification_preferences)

    kind_key = kind.to_s
    channel_key = channel.to_s
    pref = notification_preferences.dig(kind_key, channel_key)
    pref.nil? ? true : pref == true
  end
end
