class Price
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :id, :string
  attribute :product_name, :string
  attribute :unit_amount, :integer
  attribute :currency, :string
  attribute :interval, :string
  attribute :interval_count, :integer

  CACHE_KEY = "stripe_prices"
  CACHE_DURATION = 1.hour

  class << self
    def all
      Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_DURATION) do
        fetch_from_stripe
      end
    end

    def find(price_id)
      all.find { |p| p.id == price_id }
    end

    def clear_cache
      Rails.cache.delete(CACHE_KEY)
    end

    private

    def fetch_from_stripe
      prices = Stripe::Price.list(active: true, type: "recurring", expand: [ "data.product" ])
      prices.data.map do |stripe_price|
        new(
          id: stripe_price.id,
          product_name: stripe_price.product.name,
          unit_amount: stripe_price.unit_amount,
          currency: stripe_price.currency,
          interval: stripe_price.recurring.interval,
          interval_count: stripe_price.recurring.interval_count
        )
      end
    end
  end

  def formatted_amount
    dollars = unit_amount.to_f / 100
    format("$%.2f", dollars)
  end

  def formatted_interval
    if interval_count == 1
      "per #{interval}"
    else
      "every #{interval_count} #{interval}s"
    end
  end
end
