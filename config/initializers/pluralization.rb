I18n::Backend::Simple.include I18n::Backend::Pluralization

Rails.application.config.after_initialize do
  I18n.backend.store_translations :ru, i18n: {
    plural: {
      rule: lambda { |n|
        n ||= 0
        mod10 = n % 10
        mod100 = n % 100

        if mod10 == 1 && mod100 != 11
          :one
        elsif mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)
          :few
        elsif mod10 == 0 || (mod10 >= 5 && mod10 <= 9) || (mod100 >= 11 && mod100 <= 14)
          :many
        else
          :other
        end
      }
    }
  }
end
