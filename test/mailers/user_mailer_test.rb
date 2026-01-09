require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  test "magic_link" do
    mail = UserMailer.magic_link
    assert_equal "Magic link", mail.subject
    assert_equal [ "to@example.org" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match "Hi", mail.body.encoded
  end
end
