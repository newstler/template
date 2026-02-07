module Madmin
  module SettingsHelper
    def mask_secret(value)
      return nil if value.blank?

      "***#{value.last(4)}"
    end
  end
end
