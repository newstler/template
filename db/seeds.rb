# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create first admin
admin = Admin.find_or_create_by!(email: "admin@example.com")
puts "✓ Admin created: #{admin.email}"

# Seed languages
languages = [
  { code: "en", name: "English", native_name: "English" },
  { code: "es", name: "Spanish", native_name: "Espa\u00f1ol" },
  { code: "fr", name: "French", native_name: "Fran\u00e7ais" },
  { code: "de", name: "German", native_name: "Deutsch" },
  { code: "pt", name: "Portuguese", native_name: "Portugu\u00eas" },
  { code: "it", name: "Italian", native_name: "Italiano" },
  { code: "nl", name: "Dutch", native_name: "Nederlands" },
  { code: "ja", name: "Japanese", native_name: "\u65e5\u672c\u8a9e" },
  { code: "ko", name: "Korean", native_name: "\ud55c\uad6d\uc5b4" },
  { code: "zh", name: "Chinese", native_name: "\u4e2d\u6587" },
  { code: "ru", name: "Russian", native_name: "\u0420\u0443\u0441\u0441\u043a\u0438\u0439" },
  { code: "ar", name: "Arabic", native_name: "\u0627\u0644\u0639\u0631\u0628\u064a\u0629" }
]

languages.each do |attrs|
  Language.find_or_create_by!(code: attrs[:code]) do |lang|
    lang.name = attrs[:name]
    lang.native_name = attrs[:native_name]
  end
end
puts "✓ #{Language.count} languages seeded"
