require "test_helper"

class ApplicationNotifierTest < ActiveSupport::TestCase
  test "ApplicationNotifier inherits from Noticed::Event" do
    assert_equal Noticed::Event, ApplicationNotifier.superclass
  end
end
