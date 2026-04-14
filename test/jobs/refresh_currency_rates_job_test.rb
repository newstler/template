require "test_helper"

class RefreshCurrencyRatesJobTest < ActiveJob::TestCase
  test "no-op when api key is missing" do
    Setting.instance.update!(currencylayer_api_key: nil)
    assert_nothing_raised { RefreshCurrencyRatesJob.perform_now }
  end

  test "no-op when bank does not respond to update_rates" do
    fake_bank = Object.new
    original_bank = Money.default_bank
    Money.default_bank = fake_bank
    begin
      assert_nothing_raised { RefreshCurrencyRatesJob.perform_now }
    ensure
      Money.default_bank = original_bank
    end
  end

  test "calls update_rates when api key is configured" do
    Setting.instance.update!(currencylayer_api_key: "test_key")
    original_bank = Money.default_bank
    # Configure the bank's access_key so the guard clause passes.
    original_bank.access_key = "test_key"

    calls = 0
    original_bank.define_singleton_method(:update_rates) { calls += 1 }

    RefreshCurrencyRatesJob.perform_now

    assert_equal 1, calls
  ensure
    Setting.instance.update!(currencylayer_api_key: nil)
  end
end
