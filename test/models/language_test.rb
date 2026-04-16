require "test_helper"

class LanguageTest < ActiveSupport::TestCase
  test "requires code, name, and native_name" do
    I18n.with_locale(:en) do
      lang = Language.new
      assert_not lang.valid?
      assert_includes lang.errors[:code], "can't be blank"
      assert_includes lang.errors[:name], "can't be blank"
      assert_includes lang.errors[:native_name], "can't be blank"
    end
  end

  test "validates uniqueness of code" do
    I18n.with_locale(:en) do
      existing = languages(:english)
      lang = Language.new(code: existing.code, name: "Duplicate", native_name: "Dup")
      assert_not lang.valid?
      assert_includes lang.errors[:code], "has already been taken"
    end
  end

  test "english? and Language.english identify English" do
    assert languages(:english).english?
    assert_not languages(:spanish).english?
    assert_equal languages(:english), Language.english
  end

  test "enabled scope and enabled_codes exclude disabled languages" do
    assert_includes Language.enabled, languages(:english)
    assert_includes Language.enabled, languages(:spanish)
    assert_not_includes Language.enabled, languages(:disabled_lang)

    codes = Language.enabled_codes
    assert_includes codes, "en"
    assert_includes codes, "es"
    assert_not_includes codes, "de"
  end

  test "by_name scope orders alphabetically" do
    names = Language.by_name.pluck(:name)
    assert_equal names.sort, names
  end

  test "bust cache on save" do
    Rails.cache.write("language_enabled_codes", [ "old_cached" ])
    Rails.cache.write("language_available_codes", [ "old_cached" ])
    languages(:spanish).update!(name: "Updated Spanish")
    assert_nil Rails.cache.read("language_enabled_codes")
    assert_nil Rails.cache.read("language_available_codes")
  end

  test "available_codes is sorted and based on locale yml files" do
    codes = Language.available_codes
    assert_includes codes, "en"
    assert_equal codes.sort, codes
  end

  test "rejects a language whose code has no i18n yml file" do
    lang = Language.new(code: "xx", name: "Unknown", native_name: "Unknown")
    assert_not lang.valid?
    assert_includes lang.errors[:code], "has no matching i18n yml file"
  end

  test "English and Russian locale files include stubs for tg, uz, ky, tr, sr" do
    I18n.with_locale(:en) do
      assert_equal "Tajik",   I18n.t("languages.tg")
      assert_equal "Uzbek",   I18n.t("languages.uz")
      assert_equal "Kyrgyz",  I18n.t("languages.ky")
      assert_equal "Turkish", I18n.t("languages.tr")
      assert_equal "Serbian", I18n.t("languages.sr")
    end

    I18n.with_locale(:ru) do
      assert_equal "Таджикский", I18n.t("languages.tg")
      assert_equal "Узбекский",  I18n.t("languages.uz")
      assert_equal "Киргизский", I18n.t("languages.ky")
      assert_equal "Турецкий",   I18n.t("languages.tr")
      assert_equal "Сербский",   I18n.t("languages.sr")
    end
  end
end
