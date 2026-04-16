class Notifications::PreferencesController < ApplicationController
  before_action :authenticate_user!

  CHANNELS = %w[database email].freeze

  def edit
    @notifier_kinds = self.class.notifier_kinds
    @preferences = current_user.notification_preferences || {}
  end

  def update
    prefs = sanitize_preferences(params[:notification_preferences] || {})
    current_user.update!(notification_preferences: prefs)
    redirect_to edit_notification_preferences_path,
      notice: t("controllers.notifications.preferences.update.notice")
  end

  def self.notifier_kinds
    Rails.application.eager_load! unless Rails.application.config.eager_load
    ApplicationNotifier.descendants.map { |klass| klass.name.underscore }.sort
  end

  private

  def sanitize_preferences(raw)
    allowed_kinds = self.class.notifier_kinds
    result = {}

    raw.each do |kind, channels|
      next unless allowed_kinds.include?(kind.to_s)
      next unless channels.is_a?(ActionController::Parameters) || channels.is_a?(Hash)

      channels_hash = channels.is_a?(ActionController::Parameters) ? channels.to_unsafe_h : channels
      kind_prefs = {}
      CHANNELS.each do |channel|
        if channels_hash.key?(channel) || channels_hash.key?(channel.to_sym)
          value = channels_hash[channel] || channels_hash[channel.to_sym]
          kind_prefs[channel] = ActiveModel::Type::Boolean.new.cast(value)
        end
      end
      result[kind.to_s] = kind_prefs unless kind_prefs.empty?
    end

    result
  end
end
