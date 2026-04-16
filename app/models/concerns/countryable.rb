module Countryable
  extend ActiveSupport::Concern

  class_methods do
    # Usage:
    #   class Team < ApplicationRecord
    #     include Countryable
    #     countryable :country_code
    #   end
    #
    # Adds validation + `country`, `country_name`, `country_flag` readers
    # bound to the given column.
    def countryable(column = :country_code)
      validates column, inclusion: { in: ->(_) { ISO3166::Country.codes } }, allow_nil: true

      define_method(:country) do
        code = send(column)
        code.present? ? ISO3166::Country.new(code) : nil
      end

      define_method(:country_name) do
        country&.translations&.dig(I18n.locale) || country&.common_name
      end

      define_method(:country_flag) do
        country&.emoji_flag
      end
    end
  end
end
