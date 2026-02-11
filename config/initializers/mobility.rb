# Register content translation locales so Mobility accepts them
I18n.available_locales |= %i[en es fr de pt it nl ja ko zh ru ar]

Mobility.configure do
  plugins do
    backend :key_value

    active_record

    reader
    writer
    locale_accessors

    query

    fallbacks(
      es: :en,
      fr: :en,
      de: :en,
      pt: :en,
      it: :en,
      nl: :en,
      ja: :en,
      ko: :en,
      zh: :en,
      ru: :en,
      ar: :en
    )
  end
end
