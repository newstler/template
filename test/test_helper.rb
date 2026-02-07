ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

module SignInHelper
  def sign_in(user)
    post session_path, params: { session: { email: user.email } }
    token = user.generate_magic_link_token
    get verify_magic_link_path(token: token)
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
