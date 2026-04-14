class RefreshCurrencyRatesJob < ApplicationJob
  queue_as :low_priority

  def perform
    return unless Money.default_bank.respond_to?(:update_rates)
    return if Setting.get(:currencylayer_api_key).blank?

    Money.default_bank.update_rates
    Rails.logger.info("[RefreshCurrencyRatesJob] Rates updated.")
  rescue StandardError => e
    Rails.logger.error("[RefreshCurrencyRatesJob] Failed: #{e.message}")
    raise
  end
end
