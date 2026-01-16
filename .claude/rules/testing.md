---
description: Testing patterns for Minitest
globs: ["test/**/*.rb"]
---

# Testing Standards

## Framework

- **Minitest only** - No RSpec
- **Fixtures over factories** - Use `test/fixtures/*.yml`
- **System tests with Capybara** - For full integration tests

## Test Structure

```ruby
class CardTest < ActiveSupport::TestCase
  # Setup using fixtures
  setup do
    @card = cards(:one)
    @user = users(:admin)
  end

  # Descriptive test names
  test "can be closed by owner" do
    Current.user = @user
    @card.close
    assert @card.closed?
  end

  # Test edge cases
  test "cannot be closed when already closed" do
    @card.close
    assert_raises(ActiveRecord::RecordInvalid) { @card.close }
  end
end
```

## System Tests

```ruby
class CardsSystemTest < ApplicationSystemTestCase
  test "user can create a card" do
    sign_in users(:admin)
    visit board_path(boards(:one))

    click_on "New Card"
    fill_in "Title", with: "Test Card"
    click_on "Create Card"

    assert_text "Test Card"
  end
end
```

## Assertions

- Use `assert` and `assert_not` over `assert_equal true/false`
- Use `assert_difference` for counting changes
- Use `assert_no_difference` to verify no changes
- Use `assert_raises` for exception testing

## Coverage

- Test public methods, not private implementation
- Test happy path and error cases
- Test edge cases and boundary conditions
- Aim for behavior coverage, not line coverage

## Fixtures

```yaml
# test/fixtures/cards.yml
one:
  id: <%= ULID.generate %>
  board: main
  title: First Card
  created_at: <%= 1.day.ago %>

closed:
  id: <%= ULID.generate %>
  board: main
  title: Closed Card
  closure: card_one_closure
```

## Running Tests

```bash
rails test                           # All tests
rails test test/models/              # Directory
rails test test/models/card_test.rb  # File
rails test test/models/card_test.rb:42  # Line
```
