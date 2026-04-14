# frozen_string_literal: true

require "money/bank/currencylayer_bank"

module CurrencyConvertible
  extend ActiveSupport::Concern

  POPULAR_CURRENCIES = %w[EUR USD GBP CHF NOK SEK DKK PLN CZK HUF RON BGN TRY RUB UAH].freeze

  SUPPORTED_CURRENCIES = %w[
    AED ALL AMD ARS AUD AZN BAM BGN BHD BRL BYN CAD CHF CLP CNY COP
    CZK DKK DOP DZD EGP EUR GBP GEL HKD HUF IDR ILS INR IRR ISK JPY
    KGS KHR KRW KZT LAK LBP LKR LYD MAD MDL MKD MMK MNT MXN MYR
    NOK NZD PHP PLN RON RSD RUB SAR SEK SGD SYP THB TJS TND TRY TWD
    UAH USD UZS VND ZAR
  ].freeze

  CURRENCY_NAMES = {
    "AED" => "U.A.E. dirham",
    "ALL" => "Albanian lek",
    "AMD" => "Armenian dram",
    "ARS" => "Argentine peso",
    "AUD" => "Australian dollar",
    "AZN" => "Azerbaijani manat",
    "BAM" => "Bosnia and Herzegovina convertible mark",
    "BGN" => "Bulgarian lev",
    "BHD" => "Bahraini dinar",
    "BRL" => "Brazilian real",
    "BYN" => "Belarusian ruble",
    "CAD" => "Canadian dollar",
    "CHF" => "Swiss franc",
    "CLP" => "Chilean peso",
    "CNY" => "Chinese renminbi",
    "COP" => "Colombian peso",
    "CZK" => "Czech koruna",
    "DKK" => "Danish krone",
    "DOP" => "Dominican peso",
    "DZD" => "Algerian dinar",
    "EGP" => "Egyptian pound",
    "EUR" => "Euro",
    "GBP" => "British pound sterling",
    "GEL" => "Georgian lari",
    "HKD" => "Hong Kong dollar",
    "HUF" => "Hungarian forint",
    "IDR" => "Indonesian rupiah",
    "ILS" => "Israeli shekel",
    "INR" => "Indian rupee",
    "IRR" => "Iranian rial",
    "ISK" => "Icelandic krona",
    "JPY" => "Japanese yen",
    "KGS" => "Kyrgyzstani som",
    "KHR" => "Cambodian riel",
    "KRW" => "South Korean won",
    "KZT" => "Kazakhstani tenge",
    "LAK" => "Lao kip",
    "LBP" => "Lebanese pound",
    "LKR" => "Sri Lankan rupee",
    "LYD" => "Libyan dinar",
    "MAD" => "Moroccan dirham",
    "MDL" => "Moldovan leu",
    "MKD" => "Macedonian denar",
    "MMK" => "Myanmar kyat",
    "MNT" => "Mongolian togrog",
    "MXN" => "Mexican peso",
    "MYR" => "Malaysian ringgit",
    "NOK" => "Norwegian krone",
    "NZD" => "New Zealand dollar",
    "PHP" => "Philippine peso",
    "PLN" => "Polish zloty",
    "RON" => "Romanian leu",
    "RSD" => "Serbian dinar",
    "RUB" => "Russian ruble",
    "SAR" => "Saudi riyal",
    "SEK" => "Swedish krona",
    "SGD" => "Singapore dollar",
    "SYP" => "Syrian pound",
    "THB" => "Thai baht",
    "TJS" => "Tajikistani somoni",
    "TND" => "Tunisian dinar",
    "TRY" => "Turkish lira",
    "TWD" => "Taiwan dollar",
    "UAH" => "Ukrainian hryvnia",
    "USD" => "U.S. dollar",
    "UZS" => "Uzbekistan sum",
    "VND" => "Vietnamese dong",
    "ZAR" => "South African rand"
  }.freeze

  # ISO 3166 alpha-2 country code → ISO 4217 currency code.
  # Used by ApplicationController#detect_currency for IP-based fallback.
  COUNTRY_CURRENCY = {
    "AD" => "EUR", "AE" => "AED", "AL" => "ALL", "AM" => "AMD",
    "AR" => "ARS", "AT" => "EUR", "AU" => "AUD", "AZ" => "AZN",
    "BA" => "BAM", "BE" => "EUR", "BG" => "BGN", "BH" => "BHD",
    "BR" => "BRL", "BY" => "BYN", "CA" => "CAD", "CH" => "CHF",
    "CL" => "CLP", "CN" => "CNY", "CO" => "COP", "CY" => "EUR", "CZ" => "CZK",
    "DE" => "EUR", "DK" => "DKK", "DO" => "DOP", "DZ" => "DZD", "EE" => "EUR",
    "EG" => "EGP", "ES" => "EUR", "FI" => "EUR", "FR" => "EUR",
    "GB" => "GBP", "GE" => "GEL", "GR" => "EUR", "HK" => "HKD",
    "HR" => "EUR", "HU" => "HUF", "ID" => "IDR", "IE" => "EUR", "IL" => "ILS",
    "IN" => "INR", "IR" => "IRR", "IS" => "ISK", "IT" => "EUR",
    "JP" => "JPY", "KG" => "KGS", "KH" => "KHR", "KR" => "KRW",
    "KZ" => "KZT", "LA" => "LAK", "LB" => "LBP", "LK" => "LKR",
    "LT" => "EUR", "LU" => "EUR", "LV" => "EUR", "LY" => "LYD", "MA" => "MAD",
    "MD" => "MDL", "ME" => "EUR", "MK" => "MKD", "MM" => "MMK", "MN" => "MNT",
    "MT" => "EUR", "MX" => "MXN", "MY" => "MYR", "NL" => "EUR",
    "NO" => "NOK", "NZ" => "NZD", "PH" => "PHP",
    "PL" => "PLN", "PT" => "EUR", "RO" => "RON",
    "RS" => "RSD", "RU" => "RUB", "SA" => "SAR", "SE" => "SEK", "SG" => "SGD",
    "SI" => "EUR", "SK" => "EUR", "SY" => "SYP", "TH" => "THB", "TJ" => "TJS",
    "TN" => "TND", "TR" => "TRY", "TW" => "TWD", "UA" => "UAH", "US" => "USD",
    "UZ" => "UZS", "VN" => "VND", "ZA" => "ZAR"
  }.freeze

  class << self
    def convert_amount(amount_cents, from_currency, to_currency)
      return amount_cents if from_currency == to_currency
      return 0 if amount_cents.zero?

      bank = Money.default_bank
      return amount_cents unless bank.respond_to?(:access_key) && bank.access_key.present?

      from_money = Money.new(amount_cents, from_currency)
      from_money.exchange_to(to_currency).cents
    rescue Money::Bank::UnknownRate, Money::Currency::UnknownCurrency
      amount_cents
    end
  end
end
