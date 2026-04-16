class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.visible_notifications
                                  .includes(:event)
                                  .order(created_at: :desc)
                                  .limit(100)
  end

  def show
    @notification = current_user.visible_notifications.find(params[:id])
    @notification.mark_as_read!
    redirect_to(@notification.url.presence || notifications_path)
  end

  def mark_read
    @notification = current_user.visible_notifications.find(params[:id])
    @notification.mark_as_read!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def mark_all_read
    current_user.visible_notifications.unread.mark_as_read
    redirect_to notifications_path, notice: t(".marked_all_read")
  end
end
