require "test_helper"

class AdminTest < ActiveSupport::TestCase
  setup do
    @admin = admins(:one)
  end

  test "valid with email only" do
    admin = Admin.new(email: "new@example.com")
    assert admin.valid?
  end

  test "locale validates against enabled languages" do
    @admin.locale = "en"
    assert @admin.valid?

    @admin.locale = "es"
    assert @admin.valid?
  end

  test "locale rejects disabled languages" do
    @admin.locale = "de"
    assert_not @admin.valid?
    assert @admin.errors[:locale].any?
  end

  test "locale rejects unknown codes" do
    @admin.locale = "xx"
    assert_not @admin.valid?
  end

  test "locale allows nil" do
    @admin.locale = nil
    assert @admin.valid?
  end

  test "blank locale is nilified before validation" do
    @admin.locale = ""
    assert @admin.valid?
    assert_nil @admin.locale
  end

  test "generate_magic_link_token returns a signed id" do
    token = @admin.generate_magic_link_token
    assert_kind_of String, token
    found = Admin.find_signed!(token, purpose: :magic_link)
    assert_equal @admin, found
  end
end
