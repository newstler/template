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

  test "self.find_by_code finds language by code" do
    assert_equal languages(:spanish), Language.find_by_code("es")
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

  test "prevents disabling English" do
    english = languages(:english)
    english.enabled = false
    assert_not english.save
    assert_includes english.errors[:enabled], "cannot disable English"
  end

  test "allows disabling non-English language" do
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
    languages(:spanish).update!(name: "Updated Spanish")
    # Cache should be cleared
    assert_nil Rails.cache.read("language_enabled_codes")
  end
end
