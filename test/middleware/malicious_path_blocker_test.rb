# frozen_string_literal: true

require "test_helper"

class MaliciousPathBlockerTest < ActionDispatch::IntegrationTest
  # WordPress paths
  test "blocks wp-admin requests" do
    get "/wp-admin"
    assert_response :forbidden
  end

  test "blocks wp-includes requests" do
    get "/wp-includes/something.js"
    assert_response :forbidden
  end

  test "blocks wp-content requests" do
    get "/wp-content/uploads/file.jpg"
    assert_response :forbidden
  end

  test "blocks wp-login.php requests" do
    get "/wp-login.php"
    assert_response :forbidden
  end

  test "blocks xmlrpc.php requests" do
    get "/xmlrpc.php"
    assert_response :forbidden
  end

  test "blocks wp-config requests" do
    get "/wp-config.php.bak"
    assert_response :forbidden
  end

  # PHP files
  test "blocks .php file requests" do
    get "/admin.php"
    assert_response :forbidden
  end

  test "blocks .php path segment requests" do
    get "/test.php/path"
    assert_response :forbidden
  end

  test "blocks phpinfo requests" do
    get "/phpinfo.php"
    assert_response :forbidden
  end

  test "blocks phpmyadmin requests" do
    get "/phpmyadmin/"
    assert_response :forbidden
  end

  test "blocks setup.php requests" do
    get "/setup.php"
    assert_response :forbidden
  end

  # Sensitive files
  test "blocks .env file requests" do
    get "/.env"
    assert_response :forbidden
  end

  test "blocks .git directory requests" do
    get "/.git/config"
    assert_response :forbidden
  end

  test "blocks .svn directory requests" do
    get "/.svn/entries"
    assert_response :forbidden
  end

  # Path traversal
  test "blocks path traversal attempts" do
    get "/../../etc/passwd"
    assert_response :forbidden
  end

  # Case insensitivity
  test "blocks uppercase variants" do
    get "/WP-ADMIN"
    assert_response :forbidden
  end

  test "blocks mixed case variants" do
    get "/Wp-Admin"
    assert_response :forbidden
  end

  # Legitimate paths (verify they're not blocked with 403)
  test "allows root path" do
    get "/"
    assert_not_equal 403, response.status
  end

  test "allows session path" do
    get "/session/new"
    assert_response :success
  end

  test "allows health check" do
    get "/up"
    assert_response :success
  end

  test "allows chats path for authenticated users" do
    user = users(:one)
    post session_path, params: { session: { email: user.email } }

    # Simulate authentication by setting session directly
    get "/chats"
    assert_not_equal 403, response.status
  end
end
