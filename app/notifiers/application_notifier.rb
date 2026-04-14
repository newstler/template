class ApplicationNotifier < Noticed::Event
  # Base class for all notifiers in this app.
  # Consuming apps subclass this (not Noticed::Event directly) so that
  # shared behavior — default URL helpers, required params, notification
  # method helpers — can be added here without touching every notifier.
end
