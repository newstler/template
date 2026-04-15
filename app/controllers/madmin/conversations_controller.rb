module Madmin
  class ConversationsController < Madmin::ResourceController
    skip_before_action :set_record, only: :toggle_moderation

    def toggle_moderation
      setting = Setting.instance
      setting.update!(conversation_moderation_enabled: !setting.conversation_moderation_enabled?)
      redirect_to main_app.madmin_conversations_path, notice: "Conversation moderation #{setting.conversation_moderation_enabled? ? 'enabled' : 'disabled'}"
    end

    private

    def set_record
      @record = resource.model
        .includes(:team, conversation_participants: :user, conversation_messages: :user)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:team, :conversation_participants, :conversation_messages)
      resources = resources.where("conversations.created_at >= ?", params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
      resources = resources.where("conversations.created_at <= ?", params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
      resources.reorder(sort_column => sort_direction)
    end
  end
end
