require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # Bypass the magic-link UI. System tests that care about the auth flow
  # itself should exercise the real form via stable selectors; every other
  # system test just needs an authenticated session so the feature under
  # test is reachable.
  def sign_in_as(user)
    visit verify_magic_link_path(token: user.generate_magic_link_token)
  end
end
