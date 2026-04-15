class RechunkRecordJob < ApplicationJob
  queue_as :default

  def perform(record)
    return unless record.respond_to?(:rechunk)
    record.rechunk
  end
end
