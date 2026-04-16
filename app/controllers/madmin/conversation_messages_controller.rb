module Madmin
  class ConversationMessagesController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:user, :attachments_attachments, conversation: :teams)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:user, conversation: :teams)
      if params[:flagged] == "true"
        resources = resources.where.not(flagged_at: nil)
      elsif params[:flagged] == "false"
        resources = resources.where(flagged_at: nil)
      end
      resources = resources.where("conversation_messages.created_at >= ?", params[:created_at_from].to_date.beginning_of_day) if params[:created_at_from].present?
      resources = resources.where("conversation_messages.created_at <= ?", params[:created_at_to].to_date.end_of_day) if params[:created_at_to].present?
      resources.reorder(sort_column => sort_direction)
    end
  end
end
