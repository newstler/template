module Madmin
  class ChatsController < Madmin::ResourceController
    def scoped_resources
      resources = super.includes(:user, :model, :messages)

      if params[:created_at_from].present? && params[:created_at_to].present?
        resources = resources.where(created_at: params[:created_at_from]..params[:created_at_to])
      elsif params[:created_at].present?
        date = Date.parse(params[:created_at])
        resources = resources.where("DATE(created_at) = ?", date)
      end

      # Custom search by user email
      if params[:q].present?
        resources = resources.joins(:user).where("users.email LIKE ?", "%#{params[:q]}%")
      end

      resources
    end
  end
end
