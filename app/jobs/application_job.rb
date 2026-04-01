class ApplicationJob < ActiveJob::Base
  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked

  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Ensure RubyLLM has fresh credentials from DB before each job.
  # Config lives in process memory, so worker processes won't see
  # credentials saved by the web process after boot without this.
  before_perform { ProviderCredential.configure_ruby_llm! }
end
