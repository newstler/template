require "money/bank/currencylayer_bank"

Rails.application.config.to_prepare do
  begin
    Money.default_currency = Money::Currency.new(
      Setting.get(:default_currency).presence || "USD"
    )
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ArgumentError
    # DB not ready or key not yet in ALLOWED_KEYS
    Money.default_currency = Money::Currency.new("USD")
  end

  Money.locale_backend = :i18n
  Money.rounding_mode = BigDecimal::ROUND_HALF_UP

  bank = Money::Bank::CurrencylayerBank.new
  bank.cache = Rails.root.join("tmp/cache/money").to_s
  FileUtils.mkdir_p(bank.cache)

  begin
    if (key = Setting.get(:currencylayer_api_key).presence)
      bank.access_key = key
      bank.ttl_in_seconds = 86_400 # 24 hours
    end
  rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError, ArgumentError
    # DB not ready or column missing
  end

  Money.default_bank = bank
end
