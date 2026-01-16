---
name: run-tests
description: Run tests with various options and report results
---

# Run Tests

Execute tests and report results.

## Quick Test Run

```bash
rails test
```

## Test Options

### By Type

```bash
# Model tests
rails test test/models/

# Controller tests
rails test test/controllers/

# System tests (browser)
rails test:system

# All tests
rails test test/
```

### By File or Line

```bash
# Specific file
rails test test/models/card_test.rb

# Specific line (single test)
rails test test/models/card_test.rb:42
```

### By Name Pattern

```bash
# Tests matching pattern
rails test -n /close/
rails test -n /can_be_closed/
```

### With Options

```bash
# Verbose output
rails test --verbose

# Stop on first failure
rails test --fail-fast

# Run in parallel
rails test --parallel
```

## Interpreting Results

### Success
```
Finished in 1.234567s, 50.0000 runs/s, 100.0000 assertions/s.
10 runs, 20 assertions, 0 failures, 0 errors, 0 skips
```

### Failure
```
Failure:
CardTest#test_can_be_closed [test/models/card_test.rb:15]:
Expected false to be truthy.
```

Action: Check the assertion, verify fixture data, debug the model method.

### Error
```
Error:
CardTest#test_can_be_closed:
NoMethodError: undefined method `close' for #<Card...>
```

Action: Method doesn't exist, check model implementation.

## After Tests

If all tests pass:
```bash
bundle exec rubocop -A
bundle exec brakeman -q
```

If tests fail:
1. Read the failure message
2. Check the test code
3. Check the fixture data
4. Debug the implementation
5. Re-run the specific failing test
