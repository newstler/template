module DashboardHelper
  # Renders a KPI card via the shared partial.
  def kpi_card(label:, value:, trend: nil, icon: nil, href: nil, gradient: nil)
    render "shared/kpi_card", label: label, value: value, trend: trend, icon: icon, href: href, gradient: gradient
  end

  # Returns the percent change between current and previous values.
  # Returns nil if previous is zero or nil.
  def pct_change(current, previous)
    return nil if previous.nil? || previous.zero?
    ((current - previous) / previous.to_f * 100).round(1)
  end

  # Returns an arrow glyph for a change delta.
  def trend_arrow(delta)
    return "" if delta.nil?
    if delta > 0
      "↑"
    elsif delta < 0
      "↓"
    else
      "→"
    end
  end

  # Renders a circular progress ring SVG. Generic version of sailing_plus's
  # crew/adventure progress rings.
  def progress_ring(value:, max:, size: 48, label: nil, color: "accent")
    percent = max.to_i.zero? ? 0 : [ (value.to_f / max * 100).round, 100 ].min
    radius = (size - 8) / 2
    circumference = 2 * Math::PI * radius
    offset = circumference - (percent / 100.0) * circumference

    render "shared/progress_ring",
      size: size,
      radius: radius,
      circumference: circumference,
      offset: offset,
      percent: percent,
      label: label,
      color: color
  end

  # Renders an SVG sparkline for a series of numbers.
  # Originally views_sparkline in sailing_plus.
  def sparkline(series, width: 120, height: 32, color: "accent")
    return "".html_safe if series.blank?
    max = series.max.to_f
    min = series.min.to_f
    range = (max - min).zero? ? 1 : (max - min)

    points = series.each_with_index.map { |value, i|
      x = (series.size <= 1) ? 0 : (i.to_f / (series.size - 1)) * width
      y = height - ((value - min) / range) * height
      "#{x.round(1)},#{y.round(1)}"
    }.join(" ")

    svg = <<~SVG.html_safe
      <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}"
           data-controller="sparkline" class="sparkline text-#{color}-500">
        <polyline points="#{points}" fill="none" stroke="currentColor" stroke-width="1.5" />
      </svg>
    SVG
    svg
  end

  # Renders the attention items strip from a list of hashes.
  # Each item: { severity:, label:, path: (optional), count: (optional) }
  def attention_items_strip(items)
    return "".html_safe if items.blank?
    render "shared/attention_items_strip", items: items
  end

  # Wraps expensive dashboard aggregations in a cache.
  # Key includes team_id + key_name + @range so invalidation is automatic.
  def cached_dashboard(key, expires_in: 5.minutes, &block)
    team_id = respond_to?(:current_team) ? current_team&.id : nil
    range_key = @range&.then { |r| r.begin.to_date.to_s }
    cache_key = [ "dashboard", team_id, key, range_key ].compact
    Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
  end

  # Parses a range query param ("7d", "30d", "90d", "custom") into a Range.
  def time_range_from(param)
    case param.to_s
    when "7d"  then 7.days.ago..Time.current
    when "90d" then 90.days.ago..Time.current
    else 30.days.ago..Time.current
    end
  end
end
