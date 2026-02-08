require "test_helper"

class AdminMailerTest < ActionMailer::TestCase
  test "magic_link" do
    admin = admins(:one)
    mail = AdminMailer.magic_link(admin)

    assert_equal "Your admin magic link to sign in", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_match "sign in", mail.body.encoded.downcase
    assert_match "admin", mail.body.encoded.downcase
  end
end
