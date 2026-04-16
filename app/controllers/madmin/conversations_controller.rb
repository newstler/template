module Madmin
  class ConversationsController < Madmin::ResourceController
    skip_before_action :set_record, only: [ :toggle_moderation, :toggle_conversations ]

    def toggle_conversations
      setting = Setting.instance
      setting.update!(conversations_enabled: !setting.conversations_enabled?)
      redirect_to main_app.madmin_conversations_path, notice: t("controllers.madmin.conversations.toggle_conversations.#{setting.conversations_enabled? ? 'enabled' : 'disabled'}")
    end

    def toggle_moderation
      setting = Setting.instance
      setting.update!(conversation_moderation_enabled: !setting.conversation_moderation_enabled?)
      redirect_to main_app.madmin_conversations_path, notice: t("controllers.madmin.conversations.toggle_moderation.#{setting.conversation_moderation_enabled? ? 'enabled' : 'disabled'}")
    end

    private

    def set_record
      @record = resource.model
        .includes(:teams, conversation_participants: :user, conversation_messages: :user)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:teams, :conversation_participants, :conversation_messages)
      resources = resources.where("conversations.created_at >= ?", params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
      resources = resources.where("conversations.created_at <= ?", params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
      resources.reorder(sort_column => sort_direction)
    end
  end
end
