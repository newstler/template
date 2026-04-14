require "test_helper"

class NotifiableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "User includes Notifiable" do
    assert User.include?(Notifiable)
  end

  test "User has_many noticed_notifications" do
    assert_respond_to @user, :notifications
    assert_kind_of ActiveRecord::Relation, @user.notifications
  end

  test "wants_notification? returns true for a kind with no preference set" do
    @user.update!(notification_preferences: {})
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? returns false when explicitly disabled" do
    @user.update!(notification_preferences: { "welcome" => { "email" => false } })
    assert_not @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? returns true when explicitly enabled" do
    @user.update!(notification_preferences: { "welcome" => { "email" => true } })
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? is not affected by other kinds' preferences" do
    @user.update!(notification_preferences: { "deal_confirmed" => { "email" => false } })
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end
end
