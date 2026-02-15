# Discover locales from config/locales directory (yml files and subdirectories)
locale_path = Rails.root.join("config/locales")
discovered_locales = Dir.children(locale_path).filter_map { |entry|
  entry.delete_suffix(".yml").to_sym if entry.end_with?(".yml") || File.directory?(locale_path.join(entry))
}.uniq

# Register all discovered locales so Mobility accepts them
I18n.available_locales |= discovered_locales

# Build fallbacks: every non-default locale falls back to the default locale
locale_fallbacks = (discovered_locales - [ I18n.default_locale ]).each_with_object({}) do |locale, hash|
  hash[locale] = I18n.default_locale
end

Mobility.configure do
  plugins do
    backend :key_value

    active_record

    reader
    writer
    locale_accessors

    query

    fallbacks(locale_fallbacks)
  end
end
