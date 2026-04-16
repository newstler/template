module Madmin
  class ConversationParticipantsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:user, conversation: :teams)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = resources.includes(:user, conversation: :teams)

      resources = resources.where(conversation_id: params[:conversation_id]) if params[:conversation_id].present?
      resources = resources.where(user_id: params[:user_id]) if params[:user_id].present?

      if params[:status].present?
        case params[:status]
        when "never_read"
          resources = resources.where(last_read_at: nil)
        when "read"
          resources = resources.where.not(last_read_at: nil)
        end
      end

      dir = sort_direction == "asc" ? "ASC" : "DESC"

      case sort_column
      when "user_name"
        resources.joins(:user).reorder(Arel.sql("COALESCE(users.name, users.email) #{dir}"))
      when "conversation_title"
        resources.joins(:conversation).reorder(Arel.sql("conversations.title #{dir}"))
      else
        resources.reorder(sort_column => sort_direction)
      end
    end
  end
end
