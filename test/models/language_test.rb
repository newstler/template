require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "validates presence of code" do
    lang = Language.new(name: "Test", native_name: "Test")
    assert_not lang.valid?
    assert_includes lang.errors[:code], "can't be blank"
  end

  test "validates uniqueness of code" do
    existing = languages(:english)
    lang = Language.new(code: existing.code, name: "Duplicate", native_name: "Dup")
    assert_not lang.valid?
    assert_includes lang.errors[:code], "has already been taken"
  end

  test "validates presence of name" do
    lang = Language.new(code: "xx", native_name: "Test")
    assert_not lang.valid?
    assert_includes lang.errors[:name], "can't be blank"
  end

  test "validates presence of native_name" do
    lang = Language.new(code: "xx", name: "Test")
    assert_not lang.valid?
    assert_includes lang.errors[:native_name], "can't be blank"
  end

  test "english? returns true for English" do
    assert languages(:english).english?
  end

  test "english? returns false for non-English" do
    assert_not languages(:spanish).english?
  end

  test "self.english finds the English language" do
    assert_equal languages(:english), Language.english
  end

  test "enabled scope returns only enabled languages" do
    enabled = Language.enabled
    assert_includes enabled, languages(:english)
    assert_includes enabled, languages(:spanish)
    assert_not_includes enabled, languages(:disabled_lang)
  end

  test "by_name scope orders by name" do
    names = Language.by_name.pluck(:name)
    assert_equal names.sort, names
  end

  test "allows disabling any language" do
    spanish = languages(:spanish)
    spanish.update!(enabled: false)
    assert_not spanish.enabled?
  end

  test "enabled_codes returns codes of enabled languages" do
    codes = Language.enabled_codes
    assert_includes codes, "en"
    assert_includes codes, "es"
    assert_not_includes codes, "de"
  end

  test "bust cache on save" do
    Rails.cache.write("language_enabled_codes", [ "old_cached" ])
    Rails.cache.write("language_available_codes", [ "old_cached" ])
    languages(:spanish).update!(name: "Updated Spanish")
    assert_nil Rails.cache.read("language_enabled_codes")
    assert_nil Rails.cache.read("language_available_codes")
  end

  test "available_codes returns codes matching yml files in config/locales" do
    codes = Language.available_codes
    assert_includes codes, "en"
    assert_kind_of Array, codes
    assert_equal codes.sort, codes, "available_codes should be sorted"
  end

  test "cannot create language with code that has no yml file" do
    lang = Language.new(code: "xx", name: "Unknown", native_name: "Unknown")
    assert_not lang.valid?
    assert_includes lang.errors[:code], "has no matching i18n yml file"
  end
end
