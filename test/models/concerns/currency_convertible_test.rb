require "test_helper"

class CurrencyConvertibleTest < ActiveSupport::TestCase
  test "POPULAR_CURRENCIES is a subset of SUPPORTED_CURRENCIES" do
    assert (CurrencyConvertible::POPULAR_CURRENCIES - CurrencyConvertible::SUPPORTED_CURRENCIES).empty?
  end

  test "CURRENCY_NAMES covers every supported currency" do
    missing = CurrencyConvertible::SUPPORTED_CURRENCIES - CurrencyConvertible::CURRENCY_NAMES.keys
    assert_empty missing, "Missing CURRENCY_NAMES entries for: #{missing.join(', ')}"
  end

  test "COUNTRY_CURRENCY maps known countries to currencies" do
    assert_equal "USD", CurrencyConvertible::COUNTRY_CURRENCY["US"]
    assert_equal "EUR", CurrencyConvertible::COUNTRY_CURRENCY["DE"]
    assert_equal "GBP", CurrencyConvertible::COUNTRY_CURRENCY["GB"]
  end

  test "convert_amount short-circuits when amount or currencies match, and falls back when bank is unconfigured" do
    assert_equal 10_000, CurrencyConvertible.convert_amount(10_000, "USD", "USD")
    assert_equal 0, CurrencyConvertible.convert_amount(0, "USD", "EUR")

    # Test environment has no currencylayer_api_key → falls back to identity conversion
    assert_equal 10_000, CurrencyConvertible.convert_amount(10_000, "USD", "EUR")
  end
end
