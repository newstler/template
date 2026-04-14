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
end
