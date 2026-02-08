require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "magic_link" do
    user = users(:one)
    mail = UserMailer.magic_link(user)

    assert_equal "Your magic link to sign in", mail.subject
    assert_equal [ user.email ], mail.to
    assert_match "sign in", mail.body.encoded.downcase
    assert_match user.name.downcase, mail.body.encoded.downcase
  end
end
