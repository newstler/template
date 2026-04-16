require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "currency_symbol returns a symbol for known codes" do
    assert_equal "$", currency_symbol("USD")
    assert_equal "€", currency_symbol("EUR")
  end

  test "currency_symbol returns the code as-is for unknown" do
    assert_equal "XXX", currency_symbol("XXX")
  end

  test "currency_name looks up via i18n" do
    I18n.with_locale(:en) do
      assert_equal "US Dollar", currency_name("USD")
    end
  end

  test "format_amount returns nil for nil" do
    assert_nil format_amount(nil)
  end

  test "format_amount delimits thousands in en" do
    I18n.with_locale(:en) { assert_equal "1,000,000", format_amount(1_000_000) }
  end

  test "format_amount uses locale delimiter for ru" do
    I18n.with_locale(:ru) { assert_equal "1\u00a0000\u00a0000", format_amount(1_000_000) }
  end

  test "currency_options_for_select includes popular and rest groups" do
    options = currency_options_for_select("USD")
    assert_match "USD", options.to_s
    assert_match "EUR", options.to_s
  end

  test "currency_options_for_select with include_auto prepends an auto option" do
    options = currency_options_for_select(nil, include_auto: true)
    assert_match(/Auto/, options.to_s)
  end

  test "country_name returns localized name" do
    I18n.with_locale(:en) { assert_equal "United States", country_name("US") }
  end

  test "country_name returns nil for blank code" do
    assert_nil country_name("")
    assert_nil country_name(nil)
  end

  test "country_flag returns emoji" do
    assert_equal "🇩🇪", country_flag("DE")
  end

  test "country_flag returns empty string for blank code" do
    assert_equal "", country_flag(nil)
    assert_equal "", country_flag("")
  end

  test "country_options_for_select returns a sorted list with flags" do
    html = country_options_for_select
    assert_match "🇺🇸", html.to_s
    assert_match "🇩🇪", html.to_s
  end

  test "country_options_for_select honors countries whitelist" do
    html = country_options_for_select(nil, countries: %w[US DE]).to_s
    assert_match "🇺🇸", html
    assert_match "🇩🇪", html
    assert_no_match(/🇯🇵/, html)
  end
end
