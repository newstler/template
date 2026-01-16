---
name: rails-testing
description: TDD and testing patterns for Rails applications using Minitest and fixtures. Use when writing tests, setting up test data, or debugging test failures.
trigger: test, minitest, fixture, assert, testing, spec, coverage, tdd
---

# Rails Testing Guide

## Test-Driven Development

**Write tests BEFORE implementation.**

### TDD Cycle

```
1. RED    → Write a failing test
2. GREEN  → Write minimal code to pass
3. REFACTOR → Clean up, tests stay green
```

### TDD Workflow

```ruby
# Step 1: Write the test FIRST
test "user can close a card" do
  card = cards(:open)
  assert_not card.closed?
  
  card.close
  
  assert card.closed?
  assert_equal users(:one), card.closure.closed_by
end

# Step 2: Run it - see it fail
# $ rails test test/models/card_test.rb:10

# Step 3: Implement minimal code to pass
# Step 4: Run it - see it pass
# Step 5: Refactor if needed
```

### What to Test First

| When adding... | Write first... |
|----------------|----------------|
| Model method | Unit test for the method |
| Controller action | Integration test for endpoint |
| User feature | System test with Capybara |
| Bug fix | Test that reproduces the bug |

### Test Naming

Describe behavior, not implementation:

```ruby
# ✅ Good
test "closing a card creates a closure record"
test "user cannot close cards they don't own"

# ❌ Bad
test "close method calls create_closure!"
test "Closeable concern is included"
```

## Philosophy

> "Write tests for behavior, not implementation. Use fixtures, not factories."

**Core Principles:**
- **TDD: Tests first, then implementation**
- Minitest over RSpec
- Fixtures over FactoryBot
- Test public interface
- One assertion per test (when reasonable)
- Fast tests enable TDD

## Test Types

| Type | Location | Purpose |
|------|----------|---------|
| Unit | `test/models/` | Model behavior |
| Controller | `test/controllers/` | Request/response |
| Integration | `test/integration/` | Multi-step flows |
| System | `test/system/` | Browser tests |
| Mailer | `test/mailers/` | Email content |
| Job | `test/jobs/` | Background jobs |

## Fixtures

### Basic Fixtures

```yaml
# test/fixtures/users.yml
admin:
  id: <%= ULID.generate %>
  email: admin@example.com
  name: Admin User

regular:
  id: <%= ULID.generate %>
  email: user@example.com
  name: Regular User
```

### Associations

```yaml
# test/fixtures/boards.yml
main:
  id: <%= ULID.generate %>
  name: Main Board
  owner: admin  # References users(:admin)

# test/fixtures/cards.yml
open_card:
  id: <%= ULID.generate %>
  board: main  # References boards(:main)
  author: admin
  title: Open Card

closed_card:
  id: <%= ULID.generate %>
  board: main
  author: admin
  title: Closed Card
  # Closure record creates the closed state
```

### ERB in Fixtures

```yaml
# test/fixtures/cards.yml
<% 10.times do |i| %>
card_<%= i %>:
  id: <%= ULID.generate %>
  board: main
  author: admin
  title: Card <%= i %>
  created_at: <%= i.days.ago %>
<% end %>
```

### Polymorphic Associations

```yaml
# test/fixtures/closures.yml
card_closure:
  id: <%= ULID.generate %>
  closeable: closed_card (Card)  # Type in parentheses
  closed_by: admin
```

## Model Tests

```ruby
# test/models/card_test.rb
class CardTest < ActiveSupport::TestCase
  setup do
    @card = cards(:open_card)
    @user = users(:admin)
    Current.user = @user
  end

  teardown do
    Current.reset
  end

  test "belongs to board" do
    assert_equal boards(:main), @card.board
  end

  test "can be closed" do
    assert_not @card.closed?
    @card.close
    assert @card.closed?
    assert_equal @user, @card.closure.closed_by
  end

  test "cannot close twice" do
    @card.close
    assert_raises(ActiveRecord::RecordInvalid) { @card.close }
  end

  test "open scope excludes closed cards" do
    closed = cards(:closed_card)
    assert_includes Card.open, @card
    assert_not_includes Card.open, closed
  end
end
```

## Controller Tests

```ruby
# test/controllers/cards_controller_test.rb
class CardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @card = cards(:open_card)
    sign_in @user
  end

  test "index shows cards" do
    get cards_path
    assert_response :success
    assert_select "article.card", minimum: 1
  end

  test "show displays card" do
    get card_path(@card)
    assert_response :success
    assert_select "h1", @card.title
  end

  test "create redirects to card" do
    assert_difference "Card.count" do
      post cards_path, params: {
        card: { title: "New Card", board_id: boards(:main).id }
      }
    end
    assert_redirected_to card_path(Card.last)
  end

  test "unauthorized user cannot create" do
    sign_out
    post cards_path, params: { card: { title: "Test" } }
    assert_redirected_to new_session_path
  end
end
```

## System Tests

```ruby
# test/system/cards_test.rb
class CardsTest < ApplicationSystemTestCase
  setup do
    @user = users(:admin)
    sign_in @user
  end

  test "creating a card" do
    visit board_path(boards(:main))

    click_on "New Card"
    fill_in "Title", with: "System Test Card"
    fill_in "Description", with: "Created via system test"
    click_on "Create Card"

    assert_text "System Test Card"
    assert_text "Card was successfully created"
  end

  test "closing a card" do
    card = cards(:open_card)
    visit card_path(card)

    click_on "Close Card"

    assert_text "Card closed"
    assert_selector ".badge", text: "Closed"
  end

  test "inline editing with Turbo" do
    card = cards(:open_card)
    visit card_path(card)

    within turbo_frame("card_#{card.id}") do
      click_on "Edit"
      fill_in "Title", with: "Updated Title"
      click_on "Save"
    end

    assert_text "Updated Title"
    # Page didn't fully reload
    assert_no_selector ".loading"
  end
end
```

## Test Helpers

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  parallelize(workers: :number_of_processors)
  fixtures :all

  # Sign in helper
  def sign_in(user)
    post session_path, params: { email: user.email }
    follow_magic_link_for(user)
  end

  def sign_out
    delete session_path
  end

  private

  def follow_magic_link_for(user)
    token = user.generate_token_for(:magic_link)
    get verify_session_path(token: token)
  end
end

# test/application_system_test_case.rb
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome

  def sign_in(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_on "Send Magic Link"

    # In test, directly verify the token
    token = user.generate_token_for(:magic_link)
    visit verify_session_path(token: token)
  end
end
```

## Assertions

```ruby
# Equality
assert_equal expected, actual
assert_not_equal unexpected, actual

# Boolean
assert predicate
assert_not predicate

# Nil
assert_nil value
assert_not_nil value

# Collections
assert_includes collection, item
assert_empty collection

# Changes
assert_difference "Card.count", 1 do
  # action
end

assert_no_difference "Card.count" do
  # action
end

# Exceptions
assert_raises(ActiveRecord::RecordInvalid) { invalid_action }

# Response
assert_response :success
assert_redirected_to card_path(@card)

# HTML
assert_select "h1", "Expected Title"
assert_select "article.card", count: 5
```

## Running Tests

```bash
# All tests
rails test

# Specific file
rails test test/models/card_test.rb

# Specific test by line
rails test test/models/card_test.rb:42

# By name pattern
rails test -n /close/

# Verbose output
rails test --verbose

# Fail fast
rails test --fail-fast

# System tests
rails test:system

# With coverage
COVERAGE=true rails test
```

## Best Practices

### DO

- Test public behavior, not private methods
- Use descriptive test names
- Keep tests independent
- Use fixtures for test data
- Run tests frequently

### DON'T

- Don't test Rails itself
- Don't test private methods
- Don't share state between tests
- Don't use FactoryBot
- Don't mock everything
