require "test_helper"

class PriceTest < ActiveSupport::TestCase
  test "formatted_amount formats cents to dollars" do
    price = Price.new(unit_amount: 1900, currency: "usd")
    assert_equal "$19.00", price.formatted_amount
  end

  test "formatted_amount handles zero" do
    price = Price.new(unit_amount: 0, currency: "usd")
    assert_equal "$0.00", price.formatted_amount
  end

  test "formatted_amount handles large amounts" do
    price = Price.new(unit_amount: 99900, currency: "usd")
    assert_equal "$999.00", price.formatted_amount
  end

  test "formatted_interval for monthly" do
    price = Price.new(interval: "month", interval_count: 1)
    assert_equal "per month", price.formatted_interval
  end

  test "formatted_interval for yearly" do
    price = Price.new(interval: "year", interval_count: 1)
    assert_equal "per year", price.formatted_interval
  end

  test "formatted_interval for every 3 months" do
    price = Price.new(interval: "month", interval_count: 3)
    assert_equal "every 3 months", price.formatted_interval
  end
end
