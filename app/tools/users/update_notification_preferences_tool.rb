# frozen_string_literal: true

module Users
  class UpdateNotificationPreferencesTool < ApplicationTool
    description "Update the current user's notification preferences (hash of notifier kind → { channel => bool })"

    annotations(
      title: "Update Notification Preferences",
      read_only_hint: false,
      open_world_hint: false
    )

    arguments do
      required(:preferences).filled(:hash).description("Hash of { kind => { channel => boolean } }")
    end

    def call(preferences:)
      require_user!

      allowed_kinds = Notifications::PreferencesController.notifier_kinds
      allowed_channels = Notifications::PreferencesController::CHANNELS

      sanitized = {}
      preferences.each do |kind, channels|
        kind_key = kind.to_s
        next unless allowed_kinds.include?(kind_key)
        next unless channels.is_a?(Hash)

        kind_prefs = {}
        channels.each do |channel, value|
          channel_key = channel.to_s
          next unless allowed_channels.include?(channel_key)
          kind_prefs[channel_key] = ActiveModel::Type::Boolean.new.cast(value)
        end
        sanitized[kind_key] = kind_prefs unless kind_prefs.empty?
      end

      current_user.update!(notification_preferences: sanitized)

      success_response(
        { notification_preferences: current_user.notification_preferences },
        message: "Notification preferences updated"
      )
    rescue ActiveRecord::RecordInvalid => e
      error_response(e.message, code: "validation_error")
    end
  end
end
