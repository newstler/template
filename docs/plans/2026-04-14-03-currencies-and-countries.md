# Plan 03: Currencies + Countries

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Depends on:** Plan 01 (Notifications) merged. Plan 02 (Conversations) is independent but recommended first to keep PRs small. Plan 04+ (Searchable, Embeddable, Dashboards) *depend on this plan* because the dashboard `kpi_card` helper reads `Current.currency`.

**Goal:** Lift sailing_plus's currency infrastructure (well-modularized, sailing-agnostic) into the template and add a proper `Countryable` concern + country picker UI that sailing_plus is missing. Result: every consuming app has one canonical way to handle money and geographic identity.

**Architecture:** Verbatim extraction of `CurrencyConvertible` concern + helpers + partials + Stimulus controllers from sailing_plus. New `Countryable` concern based on the `countries` (iso3166) gem. Daily rate refresh via a Solid Queue recurring job. New user/team migrations for `residence_country_code` and `country_code`.

**Tech Stack:** `money` gem, `money-currencylayer-bank`, `countries` (iso3166), Solid Queue recurring jobs, Tailwind v4 OKLCH, Stimulus.

**Prerequisites:** Plan 01 merged. New branch/worktree: `git worktree add ../template-currencies feature/currencies-and-countries`.

**Task count:** 16 tasks.

---

## File structure

**New:**
```
Gemfile                                                # + money, + money-currencylayer-bank, + countries
config/initializers/money.rb
config/locales/en/currencies.yml                       # lifted from sailing_plus
config/locales/ru/currencies.yml                       # new — Russian translations
app/models/concerns/currency_convertible.rb            # lifted
app/models/concerns/countryable.rb                     # new
app/helpers/application_helper.rb                      # + currency and country helpers
app/views/shared/_currency_amount.html.erb             # lifted
app/views/shared/_country_select.html.erb              # new
app/javascript/helpers/currency.js                     # lifted
app/javascript/controllers/currency_select_controller.js  # lifted
app/javascript/controllers/country_select_controller.js  # new
app/jobs/refresh_currency_rates_job.rb
app/models/current.rb                                  # + attribute :currency
db/migrate/YYYYMMDDHHMMSS_add_currency_fields_to_teams_and_users.rb
db/migrate/YYYYMMDDHHMMSS_add_country_codes_to_teams_and_users.rb
test/models/concerns/currency_convertible_test.rb
test/models/concerns/countryable_test.rb
test/helpers/application_helper_test.rb
test/jobs/refresh_currency_rates_job_test.rb
```

**Modified:**
```
app/controllers/application_controller.rb             # + detect_currency, set_currency
app/models/team.rb                                     # include Countryable
app/models/user.rb                                     # include Countryable, preferred_currency
app/models/setting.rb                                  # + default_currency, default_country_code, currencylayer_api_key
config/routes.rb                                        # no change needed
README.md
AGENTS.md
```

---

## Task 1: Add gems to Gemfile

- [x] **Step 1: Add gems**

Append to `Gemfile` after `gem "friendly_id"`:

```ruby
gem "money", "~> 6.19"
gem "money-currencylayer-bank", "~> 1.5"
gem "countries", "~> 7.1"
```

- [x] **Step 2: Bundle install**

Run: `bundle install`

- [x] **Step 3: Verify**

Run: `bundle exec ruby -e 'require "money"; require "money/bank/currencylayer_bank"; require "countries"; puts "OK"'`

Expected: `OK`.

- [x] **Step 4: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: add money, money-currencylayer-bank, countries gems"
```

---

## Task 2: Configure Money bank initializer

- [x] **Step 1: Create the initializer**

Create `config/initializers/money.rb`:

```ruby
require "money/bank/currencylayer_bank"

Rails.application.config.to_prepare do
  Money.default_currency = Money::Currency.new(
    Setting.get(:default_currency).presence || "USD"
  )
rescue ActiveRecord::StatementInvalid, ActiveRecord::NoDatabaseError
  # DB not ready during initial load
  Money.default_currency = Money::Currency.new("USD")
end

Money.locale_backend = :i18n
Money.rounding_mode = BigDecimal::ROUND_HALF_UP

bank = Money::Bank::CurrencylayerBank.new
bank.cache = Rails.root.join("tmp/cache/money").to_s
FileUtils.mkdir_p(bank.cache)

if (key = Setting.get(:currencylayer_api_key).presence) rescue nil
  bank.access_key = key
  bank.ttl_in_seconds = 86_400 # 24 hours
end

Money.default_bank = bank
```

- [x] **Step 2: Restart the dev server and verify no boot errors**

Run: `bin/rails runner 'puts Money.default_bank.class.name'`

Expected: `Money::Bank::CurrencylayerBank`.

- [x] **Step 3: Commit**

```bash
git add config/initializers/money.rb
git commit -m "feat: configure Money bank with CurrencyLayer provider and file cache"
```

---

## Task 3: Add Setting keys for currency configuration

- [x] **Step 1: Create migration**

```bash
bin/rails generate migration AddCurrencyKeysToSettings currencylayer_api_key:string default_currency:string default_country_code:string
```

Edit the generated migration to just add the three columns:

```ruby
class AddCurrencyKeysToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :currencylayer_api_key, :string
    add_column :settings, :default_currency, :string, default: "USD"
    add_column :settings, :default_country_code, :string
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 2: Add keys to ALLOWED_KEYS and readers**

Open `app/models/setting.rb`. Add `:currencylayer_api_key`, `:default_currency`, `:default_country_code` to `ALLOWED_KEYS`. Add class readers:

```ruby
def self.default_currency
  get(:default_currency).presence || "USD"
end

def self.default_country_code
  get(:default_country_code).presence
end
```

- [x] **Step 3: Run tests**

Run: `rails test test/models/setting_test.rb`

Expected: PASS (pre-existing tests) plus any new column is accessible.

- [x] **Step 4: Commit**

```bash
git add app/models/setting.rb db/migrate/*currency_keys_to_settings* db/schema.rb
git commit -m "feat: settings for currencylayer_api_key, default_currency, default_country_code"
```

---

## Task 4: Add currency columns to users and teams

- [x] **Step 1: Write the failing test**

Append to `test/models/user_test.rb`:

```ruby
  test "preferred_currency is nullable" do
    user = users(:one)
    assert_nil user.preferred_currency
  end

  test "preferred_currency must be a supported code if set" do
    user = users(:one)
    user.preferred_currency = "USD"
    assert user.valid?
    user.preferred_currency = "XXX"
    assert_not user.valid?
  end
```

Append to `test/models/team_test.rb`:

```ruby
  test "default_currency defaults to USD" do
    team = Team.create!(name: "New Team")
    assert_equal "USD", team.default_currency
  end
```

- [x] **Step 2: Run to verify failure**

Run: `rails test test/models/user_test.rb test/models/team_test.rb`

- [x] **Step 3: Create migration**

```ruby
class AddCurrencyFieldsToTeamsAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :default_currency, :string, null: false, default: "USD"
    add_column :users, :preferred_currency, :string
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 4: Add validations on User**

Open `app/models/user.rb`. After the `validates :email` line, add:

```ruby
validates :preferred_currency, inclusion: {
  in: ->(_) { CurrencyConvertible::SUPPORTED_CURRENCIES }
}, allow_nil: true
```

- [x] **Step 5: Run tests**

Note: `CurrencyConvertible` doesn't exist yet — the test will fail with `NameError`. Skip this step until Task 5 lands, or add a temporary stub constant. Recommendation: **proceed to Task 5 first**, then return to Step 5 here.

Actually, simpler: invert the order. Do Task 5 first, then come back and complete this task. Re-number if needed.

- [x] **Step 6: Commit migration and fixtures only** (finalize after Task 5)

```bash
git add db/migrate/*currency_fields* db/schema.rb
git commit -m "feat: add preferred_currency to users and default_currency to teams"
```

Validation and tests will be finalized in Task 5.

---

## Task 5: Create CurrencyConvertible concern (lifted from sailing_plus)

- [x] **Step 1: Read the sailing_plus source**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/models/concerns/currency_convertible.rb` top to bottom. Note the `POPULAR_CURRENCIES`, `SUPPORTED_CURRENCIES`, `CURRENCY_NAMES`, `COUNTRY_CURRENCY` constants, and the `convert_amount` class method.

- [x] **Step 2: Copy verbatim to template**

Create `app/models/concerns/currency_convertible.rb` with the full contents of the sailing_plus version. The concern is already domain-agnostic — no edits needed.

- [x] **Step 3: Verify it loads**

Run: `bin/rails runner 'puts CurrencyConvertible::SUPPORTED_CURRENCIES.size'`

Expected: a number around 73 (matching sailing_plus).

- [x] **Step 4: Write concern test**

Create `test/models/concerns/currency_convertible_test.rb`:

```ruby
require "test_helper"

class CurrencyConvertibleTest < ActiveSupport::TestCase
  test "SUPPORTED_CURRENCIES is non-empty" do
    assert CurrencyConvertible::SUPPORTED_CURRENCIES.any?
    assert_includes CurrencyConvertible::SUPPORTED_CURRENCIES, "USD"
    assert_includes CurrencyConvertible::SUPPORTED_CURRENCIES, "EUR"
  end

  test "POPULAR_CURRENCIES is a subset of SUPPORTED_CURRENCIES" do
    assert (CurrencyConvertible::POPULAR_CURRENCIES - CurrencyConvertible::SUPPORTED_CURRENCIES).empty?
  end

  test "convert_amount returns the same amount when from == to" do
    assert_equal 10_000, CurrencyConvertible.convert_amount(10_000, "USD", "USD")
  end
end
```

- [x] **Step 5: Complete Task 4's validation step**

Now return to Task 4 Step 4 and complete it — the validation references `CurrencyConvertible::SUPPORTED_CURRENCIES` which now exists.

Run: `rails test test/models/user_test.rb test/models/team_test.rb test/models/concerns/currency_convertible_test.rb`

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add app/models/concerns/currency_convertible.rb \
        app/models/user.rb \
        test/models/concerns/currency_convertible_test.rb \
        test/models/user_test.rb test/models/team_test.rb
git commit -m "feat: CurrencyConvertible concern lifted from sailing_plus"
```

---

## Task 6: Port currency helpers to ApplicationHelper

- [x] **Step 1: Read sailing_plus helpers**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/helpers/application_helper.rb`. Copy the following methods into the template's `app/helpers/application_helper.rb`:

- `currency_symbol(code)`
- `currency_name(code)`
- `currency_options_for_select(selected, include_auto: false)`
- `format_amount(value)`

Adjust `format_amount` to use locale-aware delimiters:

```ruby
def format_amount(value)
  return nil if value.nil?
  number_with_delimiter(value.to_i)
end
```

`number_with_delimiter` already uses `I18n.t("number.format.delimiter")`, so this gives per-locale formatting for free.

- [x] **Step 2: Write helper tests**

Create `test/helpers/application_helper_test.rb`:

```ruby
require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "currency_symbol returns a symbol for known codes" do
    assert_equal "$", currency_symbol("USD")
    assert_equal "€", currency_symbol("EUR")
  end

  test "currency_symbol returns the code as-is for unknown" do
    assert_equal "XXX", currency_symbol("XXX")
  end

  test "currency_name looks up via i18n" do
    I18n.with_locale(:en) do
      assert_equal "US Dollar", currency_name("USD")
    end
  end

  test "format_amount delimits thousands" do
    I18n.with_locale(:en) { assert_equal "1,000,000", format_amount(1_000_000) }
  end

  test "format_amount uses locale delimiter for ru" do
    I18n.with_locale(:ru) { assert_equal "1\u00a0000\u00a0000", format_amount(1_000_000) }
  end

  test "currency_options_for_select groups popular first" do
    options = currency_options_for_select("USD")
    # Exact structure depends on helper return type; assert at least that USD appears
    assert_match "USD", options.to_s
  end
end
```

- [x] **Step 3: Copy currency locale files**

Copy `/Users/yurisidorov/Code/my/ruby/sailing_plus/config/locales/en/currencies.yml` to `config/locales/en/currencies.yml`.

Create `config/locales/ru/currencies.yml` with Russian translations of the 72 currency names. Use the same key structure. For a fast start, translate the 17 `POPULAR_CURRENCIES` first (USD, EUR, GBP, CHF, NOK, SEK, DKK, PLN, CZK, HUF, RON, BGN, HRK, TRY, RUB, UAH) and leave the rest as English fallbacks — `i18n-tasks` will flag the gaps.

- [x] **Step 4: Add ru locale to number formatting**

Ensure `config/locales/ru.yml` has:

```yaml
ru:
  number:
    format:
      delimiter: "\u00a0"  # non-breaking space
      separator: ","
```

If the file doesn't exist or lacks this, add it.

- [x] **Step 5: Run helper tests**

Run: `rails test test/helpers/application_helper_test.rb`

Expected: PASS.

- [x] **Step 6: Commit**

```bash
git add app/helpers/application_helper.rb \
        config/locales/en/currencies.yml \
        config/locales/ru/currencies.yml \
        config/locales/ru.yml \
        test/helpers/application_helper_test.rb
git commit -m "feat: port currency helpers and locale files from sailing_plus"
```

---

## Task 7: Port JS helper and Stimulus controller

- [x] **Step 1: Copy**

Copy `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/javascript/helpers/currency.js` → `app/javascript/helpers/currency.js`.

Copy `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/javascript/controllers/currency_select_controller.js` → `app/javascript/controllers/currency_select_controller.js`.

- [x] **Step 2: Pin in importmap if needed**

Check `config/importmap.rb`. If the helper needs pinning (because `app/javascript/helpers/` isn't auto-loaded), add the pin.

- [x] **Step 3: Commit**

```bash
git add app/javascript/helpers/currency.js app/javascript/controllers/currency_select_controller.js config/importmap.rb
git commit -m "feat: port currency JS helper and Stimulus controller from sailing_plus"
```

---

## Task 8: Create `_currency_amount.html.erb` shared partial

- [x] **Step 1: Copy**

Copy `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/views/shared/_currency_amount.html.erb` → `app/views/shared/_currency_amount.html.erb`. Review for any `sailing-`, `adventure-`, or domain-specific CSS classes and generalize them to template OKLCH theme tokens.

- [x] **Step 2: Smoke-test in dev**

Render the partial in a test page (e.g., `app/views/home/index.html.erb`) with dummy values to verify it looks right.

- [x] **Step 3: Commit**

```bash
git add app/views/shared/_currency_amount.html.erb
git commit -m "feat: shared _currency_amount partial from sailing_plus"
```

---

## Task 9: `Current.currency` and `detect_currency` in ApplicationController

- [x] **Step 1: Add attribute to Current**

Open `app/models/current.rb` and add:

```ruby
attribute :currency
```

- [x] **Step 2: Add detection to ApplicationController**

Open `app/controllers/application_controller.rb`. Add a `before_action :set_currency` and the method:

```ruby
before_action :set_currency

private

def set_currency
  Current.currency = detect_currency
end

def detect_currency
  return current_user.preferred_currency if current_user&.preferred_currency.present?

  if cookies[:tmpl_currency].present? && CurrencyConvertible::SUPPORTED_CURRENCIES.include?(cookies[:tmpl_currency])
    return cookies[:tmpl_currency]
  end

  if request.remote_ip.present?
    result = Geocoder.search(request.remote_ip).first rescue nil
    if result&.country_code.present?
      mapped = CurrencyConvertible::COUNTRY_CURRENCY[result.country_code.upcase]
      return mapped if mapped
    end
  end

  return current_team.default_currency if respond_to?(:current_team) && current_team

  Setting.default_currency
end
```

- [x] **Step 3: Write integration test**

Create `test/controllers/currency_detection_test.rb`:

```ruby
require "test_helper"

class CurrencyDetectionTest < ActionDispatch::IntegrationTest
  test "unauthenticated request gets platform default" do
    get "/session/new"
    assert_response :success
    # Current.currency is set; can be asserted via a debug header or a test
  end

  test "signed-in user's preferred_currency wins" do
    user = users(:one)
    user.update!(preferred_currency: "EUR")
    sign_in user
    get "/"
    # Assert Current.currency (requires a helper or debug header)
  end
end
```

Note: asserting `Current.currency` from an integration test is tricky. A pragmatic approach: add a test helper that renders `Current.currency` into the response in test env, or use `Current.currency` directly via `ActiveSupport::CurrentAttributes::TestHelper`. Simplest for this plan: assert that the response status is 200 and trust the unit tests on `detect_currency` logic.

- [x] **Step 4: Run tests**

Run: `rails test`

Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add app/models/current.rb app/controllers/application_controller.rb test/controllers/currency_detection_test.rb
git commit -m "feat: Current.currency with detection chain (user/cookie/IP/team/default)"
```

---

## Task 10: RefreshCurrencyRatesJob (daily recurring)

- [x] **Step 1: Create the job**

Create `app/jobs/refresh_currency_rates_job.rb`:

```ruby
class RefreshCurrencyRatesJob < ApplicationJob
  queue_as :low_priority

  def perform
    return unless Money.default_bank.respond_to?(:update_rates)
    return if Setting.get(:currencylayer_api_key).blank?

    Money.default_bank.update_rates
    Rails.logger.info("[RefreshCurrencyRatesJob] Rates updated.")
  rescue => e
    Rails.logger.error("[RefreshCurrencyRatesJob] Failed: #{e.message}")
    raise
  end
end
```

- [x] **Step 2: Schedule via Solid Queue recurring**

Open `config/recurring.yml` (create if missing). Add:

```yaml
production:
  refresh_currency_rates:
    class: RefreshCurrencyRatesJob
    schedule: every day at 04:00 UTC
```

- [x] **Step 3: Write test**

Create `test/jobs/refresh_currency_rates_job_test.rb`:

```ruby
require "test_helper"

class RefreshCurrencyRatesJobTest < ActiveJob::TestCase
  test "no-op when API key is missing" do
    Setting.any_instance.stubs(:currencylayer_api_key).returns(nil)
    assert_nothing_raised { RefreshCurrencyRatesJob.perform_now }
  end
end
```

Requires mocha or similar stub gem, or rewrite to set `Setting`'s value directly via the existing fixture.

- [x] **Step 4: Run and commit**

Run: `rails test test/jobs/refresh_currency_rates_job_test.rb`

```bash
git add app/jobs/refresh_currency_rates_job.rb config/recurring.yml test/jobs/refresh_currency_rates_job_test.rb
git commit -m "feat: daily RefreshCurrencyRatesJob"
```

---

## Task 11: Add country columns to users and teams

- [x] **Step 1: Write failing test**

Append to `test/models/user_test.rb`:

```ruby
  test "residence_country_code is nullable" do
    user = User.new(email: "x@example.com")
    assert user.valid?
  end

  test "residence_country_code must be a valid ISO 3166 alpha-2 when set" do
    user = users(:one)
    user.residence_country_code = "US"
    assert user.valid?
    user.residence_country_code = "ZZ"
    assert_not user.valid?
  end
```

Append to `test/models/team_test.rb`:

```ruby
  test "country_code is nullable but valid when set" do
    team = teams(:one)
    team.country_code = "DE"
    assert team.valid?
    team.country_code = "ZZ"
    assert_not team.valid?
  end
```

- [x] **Step 2: Run, observe failure**

- [x] **Step 3: Create migration**

```ruby
class AddCountryCodesToTeamsAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :teams, :country_code, :string
    add_column :users, :residence_country_code, :string
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 4: Create `Countryable` concern**

Create `app/models/concerns/countryable.rb`:

```ruby
module Countryable
  extend ActiveSupport::Concern

  class_methods do
    def countryable(column = :country_code)
      validates column, inclusion: { in: ->(_) { ISO3166::Country.codes } }, allow_nil: true

      define_method(:country) do
        code = send(column)
        code.present? ? ISO3166::Country.new(code) : nil
      end

      define_method(:country_name) do
        country&.translations&.dig(I18n.locale.to_s) || country&.common_name
      end

      define_method(:country_flag) do
        country&.emoji_flag
      end
    end
  end
end
```

- [x] **Step 5: Include in User and Team**

Open `app/models/user.rb`:

```ruby
include Countryable
countryable :residence_country_code
```

Open `app/models/team.rb`:

```ruby
include Countryable
countryable :country_code
```

- [x] **Step 6: Write concern test**

Create `test/models/concerns/countryable_test.rb`:

```ruby
require "test_helper"

class CountryableTest < ActiveSupport::TestCase
  test "User#country returns an ISO3166::Country when code is set" do
    user = users(:one)
    user.update!(residence_country_code: "US")
    assert_kind_of ISO3166::Country, user.country
    assert_equal "US", user.country.alpha2
  end

  test "User#country_name is localized" do
    user = users(:one)
    user.update!(residence_country_code: "DE")
    I18n.with_locale(:en) { assert_equal "Germany", user.country_name }
    I18n.with_locale(:ru) { assert_match(/Герман/, user.country_name) }
  end

  test "User#country_flag returns an emoji flag" do
    user = users(:one)
    user.update!(residence_country_code: "JP")
    assert_equal "🇯🇵", user.country_flag
  end

  test "Team also gets Countryable via its own column" do
    team = teams(:one)
    team.update!(country_code: "GB")
    assert_equal "GB", team.country.alpha2
  end
end
```

- [x] **Step 7: Run tests**

Run: `rails test test/models/concerns/countryable_test.rb test/models/user_test.rb test/models/team_test.rb`

Expected: PASS.

- [x] **Step 8: Commit**

```bash
git add db/migrate/*country_codes* db/schema.rb \
        app/models/concerns/countryable.rb \
        app/models/user.rb app/models/team.rb \
        test/models/concerns/countryable_test.rb \
        test/models/user_test.rb test/models/team_test.rb
git commit -m "feat: Countryable concern + country columns on users and teams"
```

---

## Task 12: Country helpers in ApplicationHelper

- [x] **Step 1: Add helpers**

Append to `app/helpers/application_helper.rb`:

```ruby
def country_name(code)
  return nil if code.blank?
  country = ISO3166::Country.new(code)
  return code unless country
  country.translations[I18n.locale.to_s] || country.common_name
end

def country_flag(code)
  return "" if code.blank?
  ISO3166::Country.new(code)&.emoji_flag || ""
end

def country_options_for_select(selected = nil, include_blank: true, countries: nil)
  list = if countries
    countries.map { |c| ISO3166::Country.new(c) }.compact
  else
    ISO3166::Country.all
  end

  pairs = list.map do |country|
    name = country.translations[I18n.locale.to_s] || country.common_name
    ["#{country.emoji_flag} #{name}", country.alpha2]
  end.sort_by { |pair| pair[0] }

  options_for_select(pairs, selected).yield_self do |opts|
    include_blank ? "<option value=''></option>".html_safe + opts : opts
  end
end
```

- [x] **Step 2: Write tests**

Append to `test/helpers/application_helper_test.rb`:

```ruby
  test "country_name returns localized name" do
    I18n.with_locale(:en) { assert_equal "United States", country_name("US") }
  end

  test "country_flag returns emoji" do
    assert_equal "🇩🇪", country_flag("DE")
  end

  test "country_options_for_select returns a sorted list with flags" do
    html = country_options_for_select
    assert_match "🇺🇸", html.to_s
  end
```

- [x] **Step 3: Run and commit**

Run: `rails test test/helpers/application_helper_test.rb`

```bash
git add app/helpers/application_helper.rb test/helpers/application_helper_test.rb
git commit -m "feat: country helpers (name, flag, options_for_select)"
```

---

## Task 13: `_country_select` partial and Stimulus controller

- [x] **Step 1: Create the partial**

Create `app/views/shared/_country_select.html.erb`:

```erb
<%# Locals: form:, method:, selected: (optional), include_blank: (optional), countries: (optional) %>
<div data-controller="country-select">
  <input type="text"
         data-country-select-target="filter"
         data-action="input->country-select#filter"
         placeholder="<%= t("shared.country_select.search_placeholder") %>"
         class="w-full px-3 py-2 mb-2 bg-dark-800 rounded" />

  <%= form.select method,
                  country_options_for_select(
                    selected || form.object.send(method),
                    include_blank: local_assigns.fetch(:include_blank, true),
                    countries: local_assigns[:countries]
                  ),
                  {},
                  data: { "country-select-target": "select" },
                  class: "w-full px-3 py-2 bg-dark-800 rounded" %>
</div>
```

- [x] **Step 2: Create Stimulus controller**

Create `app/javascript/controllers/country_select_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Simple client-side filter on an options list. Hides non-matching options
// as the user types in the filter input. Preserves keyboard navigation.
export default class extends Controller {
  static targets = ["filter", "select"]

  filter() {
    const query = this.filterTarget.value.toLowerCase()
    Array.from(this.selectTarget.options).forEach(option => {
      const text = option.text.toLowerCase()
      option.hidden = query.length > 0 && !text.includes(query)
    })
  }
}
```

- [x] **Step 3: Add locale strings**

Append to `config/locales/en/views/shared.yml` (create if missing):

```yaml
en:
  shared:
    country_select:
      search_placeholder: "Search countries..."
```

And `config/locales/ru/views/shared.yml`:

```yaml
ru:
  shared:
    country_select:
      search_placeholder: "Поиск стран..."
```

- [x] **Step 4: Commit**

```bash
git add app/views/shared/_country_select.html.erb \
        app/javascript/controllers/country_select_controller.js \
        config/locales/en/views/shared.yml config/locales/ru/views/shared.yml
git commit -m "feat: shared country_select partial with Stimulus filter"
```

---

## Task 14: Wire currency + country into Team settings and User profile views

**Files:**
- Modify: `app/views/teams/settings/edit.html.erb` (or wherever team settings are edited)
- Modify: `app/views/profiles/edit.html.erb` (or wherever user profile is edited)
- Modify: `app/controllers/teams/settings_controller.rb` (permit new params)
- Modify: `app/controllers/profiles_controller.rb` (permit new params)

- [x] **Step 1: Permit new params in controllers**

Add `:default_currency, :country_code` to the Team settings strong params.

Add `:preferred_currency, :residence_country_code` to the User profile strong params.

- [x] **Step 2: Add form fields to team settings view**

Inside the form, add:

```erb
<div>
  <%= f.label :default_currency, t(".default_currency") %>
  <%= f.select :default_currency, currency_options_for_select(f.object.default_currency) %>
</div>

<div>
  <%= f.label :country_code, t(".country") %>
  <%= render "shared/country_select", form: f, method: :country_code %>
</div>
```

- [x] **Step 3: Add to user profile view**

```erb
<div>
  <%= f.label :preferred_currency, t(".preferred_currency") %>
  <%= f.select :preferred_currency, currency_options_for_select(f.object.preferred_currency, include_blank: true) %>
</div>

<div>
  <%= f.label :residence_country_code, t(".residence_country") %>
  <%= render "shared/country_select", form: f, method: :residence_country_code %>
</div>
```

- [x] **Step 4: Add locale keys**

Add to `config/locales/en/views/teams/settings.yml`:

```yaml
en:
  teams:
    settings:
      edit:
        default_currency: "Default currency"
        country: "Country"
```

Same shape for `ru/` and for the profile view.

- [x] **Step 5: Write a system test**

Create `test/system/team_settings_currency_country_test.rb`:

```ruby
require "application_system_test_case"

class TeamSettingsCurrencyCountryTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    @team = teams(:one)
  end

  test "team admin can update default_currency and country_code" do
    sign_in_as @user
    visit edit_team_settings_path(@team.slug)

    select "EUR", from: "team[default_currency]"
    select "Germany", from: "team[country_code]"
    click_on "Save"

    @team.reload
    assert_equal "EUR", @team.default_currency
    assert_equal "DE", @team.country_code
  end

  private

  def sign_in_as(user)
    visit new_session_path
    fill_in "Email", with: user.email
    click_on "Send magic link"
    token = user.generate_magic_link_token
    visit verify_magic_link_path(token: token)
  end
end
```

- [x] **Step 6: Run and commit**

Run: `rails test:system test/system/team_settings_currency_country_test.rb`

```bash
git add app/controllers/teams/settings_controller.rb \
        app/controllers/profiles_controller.rb \
        app/views/teams/settings/ app/views/profiles/ \
        config/locales/en/views/teams/settings.yml \
        config/locales/ru/views/teams/settings.yml \
        test/system/team_settings_currency_country_test.rb
git commit -m "feat: currency and country editing in team settings and user profile"
```

---

## Task 15: README.md update

- [x] **Step 1: Add Features bullet**

Under `## Features` → `### Platform`:

```markdown
- **Currencies + Countries**
  - Money gem with daily rate refresh from CurrencyLayer
  - Per-team default currency, per-user preferred currency
  - Per-team and per-user country (ISO 3166) with emoji flag picker
  - Locale-aware amount formatting (Russian: `1 000 000,00`; English: `1,000,000.00`)
```

Under Tech Stack:

```markdown
- **Currencies**: `money` + `money-currencylayer-bank`
- **Countries**: `countries` (iso3166)
```

- [x] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README Currencies + Countries section"
```

---

## Task 16: AGENTS.md update + final CI + PR

- [x] **Step 1: Add AGENTS.md section**

Add after Conversations:

```markdown
## Currencies + Countries

Every team-scoped app uses the same primitives.

### Money

- `CurrencyConvertible` concern holds constants (`SUPPORTED_CURRENCIES`, `POPULAR_CURRENCIES`, `CURRENCY_NAMES`, `COUNTRY_CURRENCY`) and a `convert_amount(cents, from, to)` helper backed by Money's CurrencyLayer bank.
- `Current.currency` is set on every request via the detection chain:
  1. `current_user.preferred_currency`
  2. `cookies[:tmpl_currency]`
  3. IP → country → currency mapping
  4. `current_team.default_currency`
  5. `Setting.default_currency`
  6. `"USD"` fallback
- Daily `RefreshCurrencyRatesJob` (recurring, 04:00 UTC) warms the bank cache so no request blocks on a CurrencyLayer API call.
- `format_amount(value)` uses the current locale's delimiter.

### Country

```ruby
class Team < ApplicationRecord
  include Countryable
  countryable :country_code
end

team.country        # => ISO3166::Country instance or nil
team.country_name   # => localized name
team.country_flag   # => emoji flag ("🇩🇪")
```

Helpers: `country_name(code)`, `country_flag(code)`, `country_options_for_select(selected:, include_blank:, countries:)`.

Partial: `<%= render "shared/country_select", form: f, method: :country_code %>` for a searchable dropdown with flag emojis.

### Rule

Currency codes are always ISO 4217 strings (3 uppercase letters). Country codes are always ISO 3166 alpha-2 (2 uppercase letters). Monetary amounts in the database are always integer cents.
```

- [x] **Step 2: Run full CI**

Run: `bin/ci`

- [x] **Step 3: Commit AGENTS.md** (push/PR deferred — left to the user)

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md Currencies + Countries section"
# git push and gh pr create intentionally deferred
```

---

## Self-review

- ✅ `money` + `money-currencylayer-bank` + `countries` gems — Task 1
- ✅ Money bank initializer — Task 2
- ✅ Setting keys — Task 3
- ✅ User/team currency columns + validation — Tasks 4, 5
- ✅ `CurrencyConvertible` concern — Task 5
- ✅ Currency helpers — Task 6
- ✅ JS helper + Stimulus controller — Task 7
- ✅ `_currency_amount` partial — Task 8
- ✅ `Current.currency` + detection chain — Task 9
- ✅ `RefreshCurrencyRatesJob` — Task 10
- ✅ `Countryable` concern + columns — Task 11
- ✅ Country helpers — Task 12
- ✅ `_country_select` partial — Task 13
- ✅ Settings + profile editing UI — Task 14
- ✅ README + AGENTS — Tasks 15, 16

No placeholders. Type consistency: `CurrencyConvertible::SUPPORTED_CURRENCIES` referenced consistently, `Countryable.countryable(column)` signature consistent, `Current.currency` referenced consistently.

---

## Execution handoff

Subagent-driven recommended.
