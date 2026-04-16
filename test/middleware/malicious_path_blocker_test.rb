# frozen_string_literal: true

require "test_helper"

class MaliciousPathBlockerTest < ActionDispatch::IntegrationTest
  BLOCKED_PATHS = %w[
    /wp-admin
    /wp-includes/something.js
    /wp-content/uploads/file.jpg
    /wp-login.php
    /xmlrpc.php
    /wp-config.php.bak
    /admin.php
    /test.php/path
    /phpinfo.php
    /phpmyadmin/
    /setup.php
    /.env
    /.git/config
    /.svn/entries
    /../../etc/passwd
    /WP-ADMIN
    /Wp-Admin
  ].freeze

  BLOCKED_PATHS.each do |path|
    test "blocks #{path}" do
      get path
      assert_response :forbidden
    end
  end

  test "allows legitimate paths through the blocker" do
    get "/"
    assert_not_equal 403, response.status

    get "/session/new"
    assert_response :success

    get "/up"
    assert_response :success
  end

  test "does not block authenticated app paths" do
    user = users(:one)
    post session_path, params: { session: { email: user.email } }

    get "/chats"
    assert_not_equal 403, response.status
  end
end
