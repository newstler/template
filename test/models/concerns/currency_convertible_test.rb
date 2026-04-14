require "test_helper"

class CurrencyConvertibleTest < ActiveSupport::TestCase
  test "SUPPORTED_CURRENCIES is non-empty and includes core currencies" do
    assert CurrencyConvertible::SUPPORTED_CURRENCIES.any?
    assert_includes CurrencyConvertible::SUPPORTED_CURRENCIES, "USD"
    assert_includes CurrencyConvertible::SUPPORTED_CURRENCIES, "EUR"
  end

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

  test "convert_amount returns the same amount when from == to" do
    assert_equal 10_000, CurrencyConvertible.convert_amount(10_000, "USD", "USD")
  end

  test "convert_amount returns zero when amount is zero" do
    assert_equal 0, CurrencyConvertible.convert_amount(0, "USD", "EUR")
  end

  test "convert_amount falls back to same amount when bank has no api key" do
    # The test environment has no currencylayer_api_key, so conversion is a no-op
    assert_equal 10_000, CurrencyConvertible.convert_amount(10_000, "USD", "EUR")
  end
end
