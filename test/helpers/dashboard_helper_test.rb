require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  test "pct_change nil for zero previous" do
    assert_nil pct_change(10, 0)
    assert_nil pct_change(10, nil)
  end

  test "pct_change positive for increase" do
    assert_equal 100.0, pct_change(20, 10)
  end

  test "pct_change negative for decrease" do
    assert_equal(-50.0, pct_change(5, 10))
  end

  test "trend_arrow up/down/flat" do
    assert_equal "↑", trend_arrow(5)
    assert_equal "↓", trend_arrow(-5)
    assert_equal "→", trend_arrow(0)
    assert_equal "", trend_arrow(nil)
  end

  test "time_range_from parses 7d" do
    range = time_range_from("7d")
    assert_kind_of Range, range
    assert_in_delta 7.days.ago.to_f, range.begin.to_f, 5.0
  end

  test "time_range_from parses 90d" do
    range = time_range_from("90d")
    assert_in_delta 90.days.ago.to_f, range.begin.to_f, 5.0
  end

  test "time_range_from defaults to 30d" do
    assert_in_delta 30.days.ago.to_f, time_range_from("").begin.to_f, 5.0
    assert_in_delta 30.days.ago.to_f, time_range_from(nil).begin.to_f, 5.0
  end

  test "sparkline returns html_safe SVG" do
    svg = sparkline([ 1, 2, 3 ])
    assert svg.html_safe?
    assert_match "<svg", svg
  end

  test "sparkline handles blank input" do
    assert_equal "", sparkline(nil)
    assert_equal "", sparkline([])
  end

  test "cached_dashboard caches the block result" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    calls = 0
    5.times do
      cached_dashboard(:test_key) do
        calls += 1
        42
      end
    end
    assert_equal 1, calls
  ensure
    Rails.cache = original_cache
  end

  test "progress_ring renders SVG partial" do
    html = progress_ring(value: 3, max: 10, size: 48)
    assert_match "<svg", html
    assert_match "circle", html
  end

  test "attention_items_strip blank for empty" do
    assert_equal "", attention_items_strip([])
    assert_equal "", attention_items_strip(nil)
  end

  test "kpi_card renders label and value" do
    html = render partial: "shared/kpi_card",
                  locals: { label: "Users", value: "1,234", trend: 12 }
    assert_match "Users", html
    assert_match "1,234", html
    assert_match "12", html
  end

  test "kpi_card without trend omits trend row" do
    html = render partial: "shared/kpi_card",
                  locals: { label: "Chats", value: 42, trend: nil, icon: nil, href: nil }
    assert_match "Chats", html
    assert_no_match(/text-emerald-400|text-red-400/, html)
  end
end
