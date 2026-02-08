# frozen_string_literal: true

# Shared cost formatting and calculation for models with total_cost column
module Costable
  extend ActiveSupport::Concern

  # Format total cost for display (e.g., "$0.0012" or "<$0.0001")
  def formatted_total_cost
    cost = read_attribute(:total_cost) || 0
    return nil if cost.zero?

    if cost < 0.0001
      "<$0.0001"
    else
      "$#{'%.4f' % cost}"
    end
  end
end
