# frozen_string_literal: true

module Billing
  class ListPricesTool < ApplicationTool
    description "List available subscription prices"

    annotations(
      title: "List Prices",
      read_only_hint: true,
      open_world_hint: false
    )

    def call
      prices = Price.all

      success_response(prices.map { |p|
        {
          id: p.id,
          product_name: p.product_name,
          amount: p.formatted_amount,
          interval: p.formatted_interval,
          currency: p.currency
        }
      })
    end
  end
end
