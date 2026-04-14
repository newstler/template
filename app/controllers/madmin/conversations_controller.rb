module Madmin
  class ConversationsController < Madmin::ResourceController
    private

    def set_record
      @record = resource.model
        .includes(:team, :conversation_participants, :conversation_messages)
        .find(params[:id])
    end

    def scoped_resources
      resources = resource.model.send(valid_scope)
      resources = Madmin::Search.new(resources, resource, search_term).run
      resources = resources.includes(:team)
      resources.reorder(sort_column => sort_direction)
    end
  end
end
