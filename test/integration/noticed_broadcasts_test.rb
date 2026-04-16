require "test_helper"

class NoticedBroadcastsTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
  end

  test "creating a notification broadcasts a Turbo Stream to the recipient" do
    broadcasts = []
    original = Turbo::StreamsChannel.method(:broadcast_prepend_to)
    Turbo::StreamsChannel.singleton_class.define_method(:broadcast_prepend_to) do |*args, **kwargs|
      broadcasts << { args: args, kwargs: kwargs }
    end

    begin
      WelcomeNotifier.with(record: @user).deliver(@user)
    ensure
      Turbo::StreamsChannel.singleton_class.define_method(:broadcast_prepend_to, original)
    end

    assert_equal 1, broadcasts.size
    stream_key = broadcasts.first[:args].first
    assert_equal [ @user, :notifications ], stream_key
    assert_equal "notifications", broadcasts.first[:kwargs][:target]
    assert_equal "notifications/notification", broadcasts.first[:kwargs][:partial]
  end
end
