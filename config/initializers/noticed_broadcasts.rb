# Broadcast new notifications to each recipient's Turbo Stream so open
# inbox pages update live. User recipients only.
#
# We hook into Noticed::Event's after_commit because Noticed persists
# notifications via `insert_all!`, which bypasses model callbacks on
# Noticed::Notification itself. The event commit still fires, and by
# then the notifications have been inserted and are queryable.
ActiveSupport.on_load(:noticed_event) do
  after_commit on: :create do
    notifications.reload.each do |notification|
      next unless notification.recipient.is_a?(User)

      Turbo::StreamsChannel.broadcast_prepend_to(
        [ notification.recipient, :notifications ],
        target: "notifications",
        partial: "notifications/notification",
        locals:  { notification: notification }
      )
    end
  end
end
