# Notifications via Noticed v2 — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user-facing notifications to the Rails 8 template via the Noticed v2 gem — database + email delivery, Turbo-streamed inbox, user preferences, Madmin audit resources, and a reference `WelcomeNotifier` that consuming apps copy as their starting point.

**Architecture:** Install `noticed ~> 2`, run its installer, patch generated migrations for UUIDv7 primary keys (template-wide convention), wrap `has_noticed_notifications` in a `Notifiable` concern that adds per-kind/per-channel user preference checks, ship an `ApplicationNotifier` base class, ship a reference `WelcomeNotifier`, build the inbox (controller + views + Stimulus + Turbo Stream broadcast), add Madmin resources for audit, update README/AGENTS docs in the same commits.

**Tech Stack:** Rails 8 (main), Ruby 4.0.x, SQLite + Solid Stack, `noticed ~> 2`, Hotwire (Turbo + Stimulus), Tailwind v4 OKLCH, Madmin, UUIDv7 PKs via `sqlean`'s `uuid7()`.

**Prerequisites:**
- On branch `main` of `/Users/yurisidorov/Code/os/ruby/template`.
- `bin/dev` and `rails test` currently pass.
- Template spec reviewed at `docs/specs/template-improvements.md` §1.
- Optionally create a git worktree for this work: `git worktree add ../template-notifications feature/notifications-noticed`. The plan assumes you're working in whichever directory holds the template checkout — absolute paths below assume the canonical location; adjust if working in a worktree.

**Task count:** 18 tasks. Sequential dependencies — do not parallelize.

**Quality gate:** at the end of every task, run `bin/ci` (or `bundle exec rubocop -A && rails test && bin/brakeman --no-pager`). All must pass before committing.

---

## File structure (what this plan creates and modifies)

**New files:**

```
app/notifiers/application_notifier.rb                       # base class
app/notifiers/welcome_notifier.rb                            # reference notifier
app/models/concerns/notifiable.rb                            # recipient concern
app/mailers/notification_mailer.rb                           # Mailer base for notification emails
app/views/notification_mailer/welcome.html.erb               # reference mailer template
app/views/notification_mailer/welcome.text.erb               # text part
app/views/notifications/index.html.erb                       # inbox view
app/views/notifications/_notification.html.erb               # row wrapper
app/views/notifications/kinds/_welcome.html.erb              # per-kind partial
app/views/shared/_notifications_badge.html.erb               # navbar badge
app/controllers/notifications_controller.rb                  # inbox + mark-as-read
app/javascript/controllers/notifications_controller.js       # mark-as-read on click
app/madmin/resources/noticed_event_resource.rb
app/madmin/resources/noticed_notification_resource.rb
config/locales/en/views/notifications.yml
config/locales/ru/views/notifications.yml
config/locales/en/notifiers.yml
config/locales/ru/notifiers.yml
test/notifiers/welcome_notifier_test.rb
test/models/concerns/notifiable_test.rb
test/controllers/notifications_controller_test.rb
test/system/notifications_test.rb
db/migrate/YYYYMMDDHHMMSS_install_noticed.rb                 # from Noticed installer, patched
db/migrate/YYYYMMDDHHMMSS_add_notification_preferences_to_users.rb
```

**Modified files:**

```
Gemfile                                                      # + noticed ~> 2
Gemfile.lock
app/models/user.rb                                           # include Notifiable
config/routes.rb                                             # resources :notifications
config/routes/madmin.rb                                      # resources :noticed_events, :noticed_notifications
app/views/layouts/application.html.erb                       # navbar badge partial
test/fixtures/users.yml                                      # notification_preferences default
AGENTS.md                                                    # + Notifications top-level section + housekeeping fixes
README.md                                                    # + Features bullet + Tech Stack line
.claude/rules/multilingual.md                                # housekeeping fix (hardcoded-model line)
article-multilingual.md                                      # housekeeping footnote
```

**What this plan does NOT create** (deferred to consuming apps):
- Slack / Twilio / Vonage / FCM / APNS delivery methods — `noticed` supports them; consuming apps add the delivery config when needed
- Notification digest grouping — the Conversations extraction plan will add this
- Web Push — deferred until a consuming app needs it

---

## Task 0: Pre-flight documentation housekeeping

**Files:**
- Modify: `AGENTS.md:479`
- Modify: `.claude/rules/multilingual.md:39`
- Modify: `article-multilingual.md:47`
- Modify: `AGENTS.md` (add new section)

This is the §7 docs-cleanup item from the template spec, folded into this plan as prep work because it's tiny, zero-risk, and unblocks all subsequent per-primitive doc updates.

- [x] **Step 1: Fix `AGENTS.md:479` misleading model reference**

Open `AGENTS.md`, locate line 479 (the `TranslateContentJob` reference under the Multilingual Content section). Current text:

```
TranslateContentJob → LLM translation via gpt-4.1-nano
```

Replace with:

```
TranslateContentJob → LLM translation via the model configured in Madmin at Setting.translation_model
```

- [x] **Step 2: Fix `.claude/rules/multilingual.md:39` hardcoded-model reference**

Open `.claude/rules/multilingual.md`, locate line 39. Current text:

```
5. Job calls `RubyLLM.chat(model: "gpt-4.1-nano")` with JSON prompt
```

Replace with:

```
5. Job calls `RubyLLM.chat(model: Setting.translation_model)` with JSON prompt
```

- [x] **Step 3: Add footnote to `article-multilingual.md:47`**

Open `article-multilingual.md`. Leave the prose paragraph intact, but add a footnote after the `gpt-4.1-nano` mention:

```markdown
> **Note (added later):** the model is now configured in Madmin via `Setting.translation_model`; `gpt-4.1-nano` is the current default, not a hardcoded constant.
```

- [x] **Step 4: Add "Nothing hardcoded" rule to `AGENTS.md`**

At the end of `AGENTS.md`, before the final line, add:

```markdown
## Nothing hardcoded: all LLM models are Madmin-configurable

**Rule:** No code in `app/` may reference a specific LLM model name as a string literal. Every LLM model name must come from a `Setting` key, editable in Madmin at `/madmin/ai_models`.

Allowed:
- `Setting.translation_model`
- `Setting.default_model`
- `Setting.embedding_model` (added by Embeddable primitive)
- `Setting.moderation_model` (added by Conversations primitive)

Not allowed:
- `RubyLLM.chat(model: "gpt-4.1-nano")` ← replace with `Setting.translation_model`
- Hardcoded model fallbacks in rescue blocks ← use `Setting` everywhere, fail loudly if unset

Fixture defaults (`test/fixtures/settings.yml`) may contain concrete model names — those are development defaults, not production constants.
```

- [x] **Step 5: Run test suite to confirm nothing broke**

Run: `bin/ci`

Expected: PASS. These are pure doc changes so tests should be unaffected.

- [x] **Step 6: Commit**

```bash
git add AGENTS.md .claude/rules/multilingual.md article-multilingual.md
git commit -m "docs: remove hardcoded-model misdirection, add 'Nothing hardcoded' rule

The TranslateContentJob has read from Setting.translation_model for a
while, but three docs still described it as if gpt-4.1-nano were a
literal in the code. Fixes the three misleading references and adds a
new AGENTS.md section stating the rule explicitly so future contributors
and AI agents don't reintroduce hardcoded models."
```

---

## Task 1: Add `noticed` gem to Gemfile

**Files:**
- Modify: `Gemfile`
- Modify: `Gemfile.lock`

- [x] **Step 1: Add the gem**

Open `Gemfile`. After the line `gem "rails_error_dashboard"` (line 94), add:

```ruby

# Notifications framework — database, email, Turbo Stream, and more
# See https://github.com/excid3/noticed
gem "noticed", "~> 2.0"
```

- [x] **Step 2: Bundle install**

Run: `bundle install`

Expected: `Bundle complete!` with noticed listed in the output. If bundle fails because of dependency conflicts, investigate — do not bypass.

- [x] **Step 3: Verify the gem is available**

Run: `bundle exec ruby -e 'require "noticed"; puts Noticed::VERSION'`

Expected: prints `2.x.x` (a 2.x version string). Capture the exact version for the commit message.

- [x] **Step 4: Run test suite to confirm no regressions**

Run: `rails test`

Expected: PASS. Adding an unused gem should not break anything.

- [x] **Step 5: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "feat: add noticed ~> 2 gem for notifications framework

Noticed v2 provides database records, mailer integration, ActionCable
delivery, and adapters for Slack/Twilio/Vonage/APNS/FCM out of the box.
Template wraps it in a Notifiable concern with per-kind user preferences
in subsequent commits."
```

---

## Task 2: Install Noticed migrations and patch for UUIDv7

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_install_noticed.rb`

**Why this task is explicit:** the template uses UUIDv7 string primary keys (see `.claude/rules/migrations.md`). Noticed's installer generates migrations that default to `bigint` primary keys and `bigint` polymorphic foreign keys. We must patch the generated migration to use `:string` ids with a `uuid7()` default, and make the polymorphic columns `type: :string`, before running it.

- [x] **Step 1: Run the Noticed installer to generate migrations**

Run: `bin/rails noticed:install:migrations`

Expected: A new migration file appears in `db/migrate/` named `*_install_noticed.rb` (or similar — Noticed copies its own install migration into your app).

Verify with: `ls db/migrate/*install_noticed*`

- [x] **Step 2: Read the generated migration**

Read the file. It will create `noticed_events` and `noticed_notifications` tables. Note the current primary key configuration (bigint by default) and the polymorphic column types.

- [x] **Step 3: Patch the migration for UUIDv7**

Rewrite the generated migration to use string primary keys with `uuid7()` defaults. The final content should be:

```ruby
class InstallNoticed < ActiveRecord::Migration[8.1]
  def change
    create_table :noticed_events, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :type
      t.references :record, polymorphic: true, type: :string
      t.json :params

      t.integer :notifications_count
      t.timestamps
    end

    create_table :noticed_notifications, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.string :type
      t.references :event, null: false, foreign_key: { to_table: :noticed_events }, type: :string
      t.references :recipient, polymorphic: true, null: false, type: :string

      t.datetime :read_at
      t.datetime :seen_at

      t.timestamps
    end
  end
end
```

Note the critical changes from the stock Noticed migration:
- `id: { type: :string, default: -> { "uuid7()" } }` on both tables
- `type: :string` on the `record` polymorphic reference in `noticed_events`
- `type: :string` on the `recipient` polymorphic reference in `noticed_notifications`
- `type: :string` on the `event` foreign key reference in `noticed_notifications`
- `foreign_key: { to_table: :noticed_events }` to make the FK explicit

- [x] **Step 4: Run the migration**

Run: `bin/rails db:migrate`

Expected: migration runs cleanly. Both tables appear in `db/schema.rb`.

Verify with: `bin/rails runner 'puts Noticed::Event.table_name; puts Noticed::Notification.table_name'`

Expected output:
```
noticed_events
noticed_notifications
```

- [x] **Step 5: Verify schema was updated**

Run: `grep -A 8 "create_table \"noticed_events\"" db/schema.rb`

Expected: the schema entry uses `id: :string, default: -> { \"uuid7()\" }` and `t.string "record_type"`.

- [x] **Step 6: Run the full test suite**

Run: `rails test`

Expected: PASS. Fixtures are not yet using the new tables so this should be green.

- [x] **Step 7: Commit**

```bash
git add db/migrate/*install_noticed* db/schema.rb
git commit -m "feat: install Noticed migrations, patched for UUIDv7 primary keys

Template-wide convention is UUIDv7 string primary keys with a
sqlean-provided uuid7() default. Stock Noticed migrations use bigint,
so we patch them before running to match the rest of the schema. This
also requires :string on the polymorphic record/recipient references
and the event foreign key."
```

---

## Task 3: Add `notification_preferences` to users

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_add_notification_preferences_to_users.rb`
- Modify: `test/fixtures/users.yml`
- Modify: `test/models/user_test.rb`

- [x] **Step 1: Write the failing test**

Open `test/models/user_test.rb`. Add these tests at the end of the class, before the final `end`:

```ruby
  test "notification_preferences defaults to an empty hash" do
    user = User.create!(email: "prefs@example.com")
    assert_equal({}, user.notification_preferences)
  end

  test "notification_preferences can store per-kind per-channel toggles" do
    user = users(:one)
    user.update!(notification_preferences: { "welcome" => { "email" => false } })
    user.reload
    assert_equal false, user.notification_preferences.dig("welcome", "email")
  end
```

- [x] **Step 2: Run the test to verify it fails**

Run: `rails test test/models/user_test.rb -n /notification_preferences/`

Expected: FAIL with `NoMethodError: undefined method 'notification_preferences'` or similar missing-column error.

- [x] **Step 3: Generate the migration**

Run: `bin/rails generate migration AddNotificationPreferencesToUsers notification_preferences:json`

This creates a file like `db/migrate/YYYYMMDDHHMMSS_add_notification_preferences_to_users.rb`.

- [x] **Step 4: Edit the migration to add a default**

Open the generated migration. Replace its contents with:

```ruby
class AddNotificationPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :notification_preferences, :json, null: false, default: {}
  end
end
```

- [x] **Step 5: Run the migration**

Run: `bin/rails db:migrate`

Expected: migration runs. `db/schema.rb` shows the new column.

- [x] **Step 6: Run the test to verify it passes**

Run: `rails test test/models/user_test.rb -n /notification_preferences/`

Expected: PASS (both tests).

- [x] **Step 7: Run the full test suite**

Run: `rails test`

Expected: PASS.

- [x] **Step 8: Commit**

```bash
git add db/migrate/*notification_preferences* db/schema.rb test/models/user_test.rb
git commit -m "feat: add notification_preferences json column to users

Stores per-notifier-per-channel toggles like
{ 'welcome' => { 'email' => false, 'database' => true } }. Default is
an empty hash meaning 'all channels on' — the Notifiable concern
(next commit) interprets missing keys as opt-in."
```

---

## Task 4: Create the `Notifiable` concern

**Files:**
- Create: `app/models/concerns/notifiable.rb`
- Create: `test/models/concerns/notifiable_test.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/concerns/notifiable_test.rb`:

```ruby
require "test_helper"

class NotifiableTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "User includes Notifiable" do
    assert User.include?(Notifiable)
  end

  test "User has_many noticed_notifications" do
    assert_respond_to @user, :notifications
    assert_kind_of ActiveRecord::Relation, @user.notifications
  end

  test "wants_notification? returns true for a kind with no preference set" do
    @user.update!(notification_preferences: {})
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? returns false when explicitly disabled" do
    @user.update!(notification_preferences: { "welcome" => { "email" => false } })
    assert_not @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? returns true when explicitly enabled" do
    @user.update!(notification_preferences: { "welcome" => { "email" => true } })
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end

  test "wants_notification? is not affected by other kinds' preferences" do
    @user.update!(notification_preferences: { "deal_confirmed" => { "email" => false } })
    assert @user.wants_notification?(kind: :welcome, channel: :email)
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/models/concerns/notifiable_test.rb`

Expected: FAIL with `uninitialized constant Notifiable`.

- [ ] **Step 3: Create the concern**

Create `app/models/concerns/notifiable.rb`:

```ruby
module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :recipient, dependent: :destroy, class_name: "Noticed::Notification"
  end

  def wants_notification?(kind:, channel:)
    kind_key = kind.to_s
    channel_key = channel.to_s
    pref = notification_preferences.dig(kind_key, channel_key)
    pref.nil? ? true : pref == true
  end
end
```

- [ ] **Step 4: Include the concern in User**

Open `app/models/user.rb`. Add `include Notifiable` right after `include Costable` at line 2:

```ruby
class User < ApplicationRecord
  include Costable
  include Notifiable

  has_one_attached :avatar
  # ... rest unchanged
```

- [ ] **Step 5: Run the concern test**

Run: `rails test test/models/concerns/notifiable_test.rb`

Expected: PASS (all six tests).

- [ ] **Step 6: Run the full test suite**

Run: `rails test`

Expected: PASS. Existing user tests should still pass because `Notifiable` only adds methods; it doesn't change existing ones.

- [ ] **Step 7: Commit**

```bash
git add app/models/concerns/notifiable.rb app/models/user.rb test/models/concerns/notifiable_test.rb
git commit -m "feat: add Notifiable concern with per-kind preference helper

Notifiable wraps Noticed's has_many :notifications polymorphic
association and adds wants_notification?(kind:, channel:) for use in
deliver_by :if blocks on Notifier classes. Default is opt-in (missing
preference key means 'yes'), so new users receive all notifications
until they explicitly opt out."
```

---

## Task 5: Create `ApplicationNotifier` base class

**Files:**
- Create: `app/notifiers/application_notifier.rb`

Noticed v2 notifiers inherit from `Noticed::Event`. The template adds an `ApplicationNotifier` base class so consuming apps have a single place to add shared behavior (e.g. default URL helpers, shared `notification_methods`).

- [ ] **Step 1: Write the failing test**

Create `test/notifiers/application_notifier_test.rb`:

```ruby
require "test_helper"

class ApplicationNotifierTest < ActiveSupport::TestCase
  test "ApplicationNotifier inherits from Noticed::Event" do
    assert_equal Noticed::Event, ApplicationNotifier.superclass
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/notifiers/application_notifier_test.rb`

Expected: FAIL with `NameError: uninitialized constant ApplicationNotifier`.

- [ ] **Step 3: Create the base class**

Create `app/notifiers/application_notifier.rb`:

```ruby
class ApplicationNotifier < Noticed::Event
  # Base class for all notifiers in this app.
  # Consuming apps subclass this (not Noticed::Event directly) so that
  # shared behavior — default URL helpers, required params, notification
  # method helpers — can be added here without touching every notifier.
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `rails test test/notifiers/application_notifier_test.rb`

Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `rails test`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/notifiers/application_notifier.rb test/notifiers/application_notifier_test.rb
git commit -m "feat: add ApplicationNotifier base class

Consuming apps subclass ApplicationNotifier (not Noticed::Event directly)
so shared behavior lands in one place."
```

---

## Task 6: Create `WelcomeNotifier` and `NotificationMailer`

**Files:**
- Create: `app/notifiers/welcome_notifier.rb`
- Create: `app/mailers/notification_mailer.rb`
- Create: `app/views/notification_mailer/welcome.html.erb`
- Create: `app/views/notification_mailer/welcome.text.erb`
- Create: `test/notifiers/welcome_notifier_test.rb`
- Create: `config/locales/en/notifiers.yml`
- Create: `config/locales/ru/notifiers.yml`

- [ ] **Step 1: Write the failing test**

Create `test/notifiers/welcome_notifier_test.rb`:

```ruby
require "test_helper"

class WelcomeNotifierTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
  end

  test "delivering creates a noticed_notification for the recipient" do
    assert_difference -> { @user.notifications.count }, 1 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
    end
  end

  test "delivering sends an email when email preference is enabled (default)" do
    assert_emails 1 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
    end
  end

  test "delivering skips email when user has disabled it" do
    @user.update!(notification_preferences: { "welcome_notifier" => { "email" => false } })
    assert_emails 0 do
      WelcomeNotifier.with(record: @user).deliver(@user)
      perform_enqueued_jobs
    end
  end

  test "notification message reads from i18n" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs
    notification = @user.notifications.last
    assert_includes notification.event.message, @user.name.presence || @user.email
  end
end
```

Add this to `test/test_helper.rb` if not already there, inside the `ActiveSupport::TestCase` block:

```ruby
    include ActiveJob::TestHelper
    include ActionMailer::TestHelper
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/notifiers/welcome_notifier_test.rb`

Expected: FAIL — `WelcomeNotifier` does not exist.

- [ ] **Step 3: Create the notifier**

Create `app/notifiers/welcome_notifier.rb`:

```ruby
class WelcomeNotifier < ApplicationNotifier
  required_params :record

  deliver_by :database

  deliver_by :email do |config|
    config.mailer = "NotificationMailer"
    config.method = :welcome
    config.if     = ->(recipient) {
      recipient.wants_notification?(kind: :welcome_notifier, channel: :email)
    }
  end

  notification_methods do
    def message
      I18n.t("notifiers.welcome_notifier.message", name: display_name)
    end

    def url
      Rails.application.routes.url_helpers.notifications_path
    end

    private

    def display_name
      record = params[:record]
      record.respond_to?(:name) && record.name.present? ? record.name : record.email
    end
  end
end
```

- [ ] **Step 4: Create the mailer**

Create `app/mailers/notification_mailer.rb`:

```ruby
class NotificationMailer < ApplicationMailer
  def welcome
    @notification = params[:notification]
    @user         = @notification.recipient
    mail(to: @user.email, subject: I18n.t("notifiers.welcome_notifier.email.subject"))
  end
end
```

- [ ] **Step 5: Create the mailer templates**

Create `app/views/notification_mailer/welcome.html.erb`:

```erb
<h1><%= t("notifiers.welcome_notifier.email.heading") %></h1>

<p><%= t("notifiers.welcome_notifier.email.body_html", name: @user.name.presence || @user.email) %></p>

<p>
  <%= link_to t("notifiers.welcome_notifier.email.cta"),
              notifications_url,
              style: "display:inline-block;padding:10px 20px;background:#4f46e5;color:#fff;text-decoration:none;border-radius:6px;" %>
</p>
```

Create `app/views/notification_mailer/welcome.text.erb`:

```erb
<%= t("notifiers.welcome_notifier.email.heading") %>

<%= t("notifiers.welcome_notifier.email.body_text", name: @user.name.presence || @user.email) %>

<%= t("notifiers.welcome_notifier.email.cta") %>: <%= notifications_url %>
```

- [ ] **Step 6: Create the i18n files**

Create `config/locales/en/notifiers.yml`:

```yaml
en:
  notifiers:
    welcome_notifier:
      message: "Welcome aboard, %{name}!"
      email:
        subject: "Welcome to the team"
        heading: "Welcome aboard"
        body_html: "Hi <strong>%{name}</strong>, welcome! Your account is ready."
        body_text: "Hi %{name}, welcome! Your account is ready."
        cta: "Go to your inbox"
```

Create `config/locales/ru/notifiers.yml`:

```yaml
ru:
  notifiers:
    welcome_notifier:
      message: "Добро пожаловать, %{name}!"
      email:
        subject: "Добро пожаловать"
        heading: "Добро пожаловать"
        body_html: "Здравствуйте, <strong>%{name}</strong>! Ваша учётная запись готова."
        body_text: "Здравствуйте, %{name}! Ваша учётная запись готова."
        cta: "Перейти во входящие"
```

- [ ] **Step 7: Run the notifier test**

Run: `rails test test/notifiers/welcome_notifier_test.rb`

Expected: PASS (all four tests).

If any fail:
- Ensure `perform_enqueued_jobs` is available (requires `ActiveJob::TestHelper` in test_helper).
- Ensure `assert_emails` is available (requires `ActionMailer::TestHelper`).
- If the i18n keys aren't found, run `bundle exec i18n-tasks missing` to verify the file paths are correct.

- [ ] **Step 8: Run the full suite**

Run: `rails test`

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/notifiers/welcome_notifier.rb \
        app/mailers/notification_mailer.rb \
        app/views/notification_mailer/ \
        config/locales/en/notifiers.yml \
        config/locales/ru/notifiers.yml \
        test/notifiers/welcome_notifier_test.rb \
        test/test_helper.rb
git commit -m "feat: add WelcomeNotifier as the reference notifier + mailer

Reference pattern for consuming apps. Demonstrates the three key moves:
  1. required_params :record  — fail-fast on missing params
  2. deliver_by :email with an :if block  — respects user preferences
  3. notification_methods do ... end  — i18n-powered message/url helpers

English and Russian locale files added per the template's i18n rules."
```

---

## Task 7: `NotificationsController#index`

**Files:**
- Create: `app/controllers/notifications_controller.rb`
- Create: `app/views/notifications/index.html.erb`
- Create: `app/views/notifications/_notification.html.erb`
- Create: `app/views/notifications/kinds/_welcome.html.erb`
- Create: `config/locales/en/views/notifications.yml`
- Create: `config/locales/ru/views/notifications.yml`
- Create: `test/controllers/notifications_controller_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/notifications_controller_test.rb`:

```ruby
require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "GET /notifications renders index for authenticated user" do
    get notifications_path
    assert_response :success
  end

  test "GET /notifications lists the user's notifications newest first" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs

    get notifications_path
    assert_response :success
    assert_select "[data-notification-id]", count: 1
  end

  test "GET /notifications shows an empty state when the user has none" do
    get notifications_path
    assert_response :success
    assert_select "[data-empty-state]"
  end

  test "GET /notifications redirects unauthenticated users" do
    delete session_path
    get notifications_path
    assert_redirected_to new_session_path
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/controllers/notifications_controller_test.rb`

Expected: FAIL with `NoMethodError: undefined method 'notifications_path'` or `NameError: uninitialized constant NotificationsController`.

- [ ] **Step 3: Add the route**

Open `config/routes.rb`. After the `resource :onboarding` line (line 17), add:

```ruby
  # User notifications inbox (global — not team-scoped because a user may
  # receive notifications across multiple teams)
  resources :notifications, only: [ :index, :show ] do
    member do
      patch :mark_read
    end
    collection do
      patch :mark_all_read
    end
  end
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/notifications_controller.rb`:

```ruby
class NotificationsController < ApplicationController
  before_action :authenticate_user!

  def index
    @notifications = current_user.notifications
                                  .includes(:event)
                                  .order(created_at: :desc)
                                  .limit(100)
  end

  def show
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!
    redirect_to @notification.event.url || notifications_path
  end

  def mark_read
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def mark_all_read
    current_user.notifications.unread.mark_as_read
    redirect_to notifications_path, notice: t(".marked_all_read")
  end
end
```

- [ ] **Step 5: Create the index view**

Create `app/views/notifications/index.html.erb`:

```erb
<% content_for :title, t(".title") %>

<div class="max-w-3xl mx-auto px-4 py-8">
  <header class="flex items-center justify-between mb-6">
    <h1 class="text-2xl font-semibold"><%= t(".title") %></h1>

    <% if @notifications.any? %>
      <%= button_to t(".mark_all_read"),
                    mark_all_read_notifications_path,
                    method: :patch,
                    class: "text-sm text-dark-300 hover:text-white" %>
    <% end %>
  </header>

  <% if @notifications.any? %>
    <%= turbo_stream_from current_user, :notifications %>
    <ul id="notifications" class="space-y-2">
      <%= render partial: "notifications/notification",
                 collection: @notifications,
                 as: :notification %>
    </ul>
  <% else %>
    <div data-empty-state class="text-center py-16 text-dark-300">
      <%= inline_svg "icons/bell-off.svg", class: "w-12 h-12 mx-auto mb-4 opacity-50" %>
      <p><%= t(".empty") %></p>
    </div>
  <% end %>
</div>
```

- [ ] **Step 6: Create the notification row partial**

Create `app/views/notifications/_notification.html.erb`:

```erb
<%#
  Wrapper partial that dispatches to a per-kind partial based on the
  notifier type. The kind is derived from the notifier class name,
  underscored and demodulized: "WelcomeNotifier" → "welcome".
%>
<% kind = notification.type.to_s.demodulize.underscore.sub(/_notifier$/, "") %>
<% partial_path = "notifications/kinds/#{kind}" %>

<li data-notification-id="<%= notification.id %>"
    data-controller="notifications"
    data-action="click->notifications#markRead"
    data-notifications-mark-read-url-value="<%= mark_read_notification_path(notification) %>"
    class="<%= class_names(
      'block p-4 rounded-lg transition-colors cursor-pointer',
      'bg-dark-700 hover:bg-dark-600': notification.read_at.nil?,
      'bg-dark-800 hover:bg-dark-700 opacity-75': notification.read_at.present?
    ) %>">
  <% if lookup_context.exists?(partial_path, [], true) %>
    <%= render partial_path, notification: notification %>
  <% else %>
    <p><%= notification.event.message %></p>
    <time class="text-xs text-dark-300"><%= l(notification.created_at, format: :short) %></time>
  <% end %>
</li>
```

- [ ] **Step 7: Create the welcome kind partial**

Create `app/views/notifications/kinds/_welcome.html.erb`:

```erb
<div class="flex items-start gap-3">
  <div class="flex-shrink-0 w-10 h-10 rounded-full bg-accent-500 flex items-center justify-center">
    <%= inline_svg "icons/sparkle.svg", class: "w-5 h-5 text-white" %>
  </div>
  <div class="flex-1">
    <p class="text-sm"><%= notification.event.message %></p>
    <time class="text-xs text-dark-300">
      <%= l(notification.created_at, format: :short) %>
    </time>
  </div>
</div>
```

- [ ] **Step 8: Create the locale files**

Create `config/locales/en/views/notifications.yml`:

```yaml
en:
  notifications:
    index:
      title: "Notifications"
      empty: "No notifications yet."
      mark_all_read: "Mark all as read"
    mark_all_read:
      marked_all_read: "All notifications marked as read."
```

Create `config/locales/ru/views/notifications.yml`:

```yaml
ru:
  notifications:
    index:
      title: "Уведомления"
      empty: "Уведомлений пока нет."
      mark_all_read: "Отметить все как прочитанные"
    mark_all_read:
      marked_all_read: "Все уведомления отмечены как прочитанные."
```

- [ ] **Step 9: Add icons if not present**

Check that `app/assets/images/icons/bell-off.svg` and `app/assets/images/icons/sparkle.svg` exist. If not, create minimal placeholders:

If `bell-off.svg` is missing, create it with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M13.73 21a2 2 0 0 1-3.46 0"/><path d="M18.63 13A17.89 17.89 0 0 1 18 8"/><path d="M6.26 6.26A5.86 5.86 0 0 0 6 8c0 7-3 9-3 9h14"/><path d="M18 8a6 6 0 0 0-9.33-5"/><line x1="1" y1="1" x2="23" y2="23"/></svg>
```

If `sparkle.svg` is missing, create it with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.39 7.36H22l-6.19 4.5 2.39 7.36L12 16.72l-6.19 4.5 2.39-7.36L2 9.36h7.61z"/></svg>
```

- [ ] **Step 10: Run the controller test**

Run: `rails test test/controllers/notifications_controller_test.rb`

Expected: PASS (all four tests).

- [ ] **Step 11: Run the full suite**

Run: `rails test`

Expected: PASS.

- [ ] **Step 12: Commit**

```bash
git add app/controllers/notifications_controller.rb \
        app/views/notifications/ \
        config/routes.rb \
        config/locales/en/views/notifications.yml \
        config/locales/ru/views/notifications.yml \
        test/controllers/notifications_controller_test.rb \
        app/assets/images/icons/bell-off.svg \
        app/assets/images/icons/sparkle.svg
git commit -m "feat: add user notifications inbox at /notifications

Controller renders the user's notifications newest first with an empty
state. Per-notification partials dispatch by kind (welcome → welcome
partial). Routes include show, mark_read, and mark_all_read actions
alongside index."
```

---

## Task 8: Turbo Stream broadcast on new notification

**Files:**
- Create: `app/models/concerns/broadcastable_notification.rb` OR extend the existing Notifiable concern
- Modify: `app/notifiers/application_notifier.rb`

Noticed v2 doesn't broadcast via Turbo Streams automatically. We add it via an after-create hook on `Noticed::Notification` through an initializer that decorates the class, OR we do it via a delivery method. The cleanest path is to use an ActionCable delivery via Noticed's built-in `deliver_by :action_cable`, which we wire to the Turbo::StreamsChannel.

The simplest approach that works with Turbo's streams-from helper: create a module that Noticed notifications include, which calls `broadcast_append_to` after create.

- [ ] **Step 1: Write the failing system test**

Create `test/system/notifications_test.rb`:

```ruby
require "application_system_test_case"

class NotificationsTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
  end

  test "a new notification appears live in the inbox via Turbo Stream" do
    sign_in_as @user
    visit notifications_path

    assert_selector "[data-empty-state]"

    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs

    assert_selector "[data-notification-id]", wait: 5
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

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test:system test/system/notifications_test.rb`

Expected: FAIL because nothing broadcasts the new notification.

- [ ] **Step 3: Configure ActionCable delivery in `ApplicationNotifier`**

Replace the contents of `app/notifiers/application_notifier.rb`:

```ruby
class ApplicationNotifier < Noticed::Event
  # All notifiers in this app broadcast to the recipient's personal
  # notifications Turbo Stream. Rendered inboxes that use
  # `<%= turbo_stream_from current_user, :notifications %>` will update
  # live; pages without that helper are unaffected.
  deliver_by :action_cable do |config|
    config.channel = "Turbo::StreamsChannel"
    config.stream  = ->(recipient) {
      [recipient, :notifications]
    }
    config.message = ->(notification) {
      turbo_stream_action = Turbo::StreamsChannel.broadcast_action_later_to(
        [notification.recipient, :notifications],
        action: :prepend,
        target: "notifications",
        partial: "notifications/notification",
        locals:  { notification: notification }
      )
      turbo_stream_action
    }
  end
end
```

Note: this pattern uses the `deliver_by :action_cable` config but handles the actual broadcast via `Turbo::StreamsChannel.broadcast_action_later_to` in the `message` lambda. This is simpler than implementing a custom delivery method.

**Alternative if the `:action_cable` delivery method doesn't cooperate with Turbo Streams in v2**: instead of `deliver_by :action_cable`, add an `after_create_commit` hook on `Noticed::Notification` via a Rails initializer.

Create `config/initializers/noticed_broadcasts.rb` with:

```ruby
# Broadcast new notifications to the recipient's Turbo Stream so open
# inbox pages update live. Notifiable recipients only.
Rails.application.config.to_prepare do
  Noticed::Notification.after_create_commit do
    next unless recipient.is_a?(User)
    broadcast_prepend_to [recipient, :notifications],
                         target: "notifications",
                         partial: "notifications/notification",
                         locals:  { notification: self }
  end
end
```

If using this alternative, delete the `deliver_by :action_cable` block from `application_notifier.rb` and keep only the comment.

- [ ] **Step 4: Run the system test**

Run: `rails test:system test/system/notifications_test.rb`

Expected: PASS. The test fills in the email, signs in, visits `/notifications`, triggers a notifier in-band, and expects the row to appear via Turbo Stream within 5 seconds.

If it fails:
- Verify Solid Cable is configured (`config/cable.yml` should point to `solid_cable`).
- Verify `turbo_stream_from` is in `index.html.erb` (it was added in Task 7 step 5).
- Check the test log for any broadcast errors.

- [ ] **Step 5: Run the full suite**

Run: `rails test && rails test:system`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/notifiers/application_notifier.rb \
        config/initializers/noticed_broadcasts.rb \
        test/system/notifications_test.rb
git commit -m "feat: broadcast new notifications via Turbo Stream

Any page that renders turbo_stream_from [user, :notifications] will
receive live updates when a new notification is created. Pages without
the stream helper are unaffected — this is effectively opt-in per page.

The broadcast is implemented as an after_create_commit hook on
Noticed::Notification so it happens regardless of which delivery_by
methods the notifier uses."
```

---

## Task 9: Stimulus controller for mark-as-read on click

**Files:**
- Create: `app/javascript/controllers/notifications_controller.js`
- Modify: `app/javascript/controllers/index.js` (if using manual registration)
- Modify: `test/system/notifications_test.rb` (add an interaction test)

- [ ] **Step 1: Write the failing test**

Append to `test/system/notifications_test.rb` before the final `end`:

```ruby
  test "clicking a notification marks it as read" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs

    sign_in_as @user
    visit notifications_path

    notification = @user.notifications.last
    assert_nil notification.read_at

    find("[data-notification-id='#{notification.id}']").click

    # Wait for the turbo frame to update then verify
    assert_no_selector ".bg-dark-700[data-notification-id='#{notification.id}']"
    assert notification.reload.read_at.present?
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test:system test/system/notifications_test.rb -n /mark_as_read/`

Expected: FAIL — clicking does nothing because there's no Stimulus controller yet.

- [ ] **Step 3: Create the Stimulus controller**

Create `app/javascript/controllers/notifications_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

// Marks a notification as read when it's clicked, via a PATCH to
// mark_read_notification_path. The URL is passed in as a Stimulus value.
//
// Usage in the view:
//   data-controller="notifications"
//   data-action="click->notifications#markRead"
//   data-notifications-mark-read-url-value="<%= mark_read_notification_path(n) %>"
export default class extends Controller {
  static values = { markReadUrl: String }

  async markRead(event) {
    // Don't intercept clicks on links inside the notification body —
    // let them navigate normally.
    if (event.target.closest("a")) return

    const response = await fetch(this.markReadUrlValue, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name=csrf-token]").content,
        "Accept": "text/vnd.turbo-stream.html"
      }
    })

    if (response.ok) {
      const stream = await response.text()
      Turbo.renderStreamMessage(stream)
    }
  }
}
```

- [ ] **Step 4: Register the controller**

If the template uses `stimulus-loading` with eager loading (default in Rails 8), the file is auto-registered by name. Verify with:

Run: `cat app/javascript/controllers/index.js`

If it contains `eagerLoadControllersFrom("controllers", application)`, the new controller is picked up automatically. If it contains manual registrations, add:

```javascript
import NotificationsController from "./notifications_controller"
application.register("notifications", NotificationsController)
```

- [ ] **Step 5: Add a mark_read Turbo Stream response**

Create `app/views/notifications/mark_read.turbo_stream.erb`:

```erb
<%= turbo_stream.replace dom_id(@notification), partial: "notifications/notification", locals: { notification: @notification } %>
```

- [ ] **Step 6: Update the notification partial to use `dom_id`**

Open `app/views/notifications/_notification.html.erb`. Change the `<li data-notification-id="...">` to also include `id="<%= dom_id(notification) %>"` so the turbo_stream.replace has a target:

```erb
<li id="<%= dom_id(notification) %>"
    data-notification-id="<%= notification.id %>"
    data-controller="notifications"
    data-action="click->notifications#markRead"
    data-notifications-mark-read-url-value="<%= mark_read_notification_path(notification) %>"
    class="<%= class_names(
      'block p-4 rounded-lg transition-colors cursor-pointer',
      'bg-dark-700 hover:bg-dark-600': notification.read_at.nil?,
      'bg-dark-800 hover:bg-dark-700 opacity-75': notification.read_at.present?
    ) %>">
```

- [ ] **Step 7: Run the system test**

Run: `rails test:system test/system/notifications_test.rb`

Expected: PASS (both system tests).

- [ ] **Step 8: Run the full suite**

Run: `rails test && rails test:system`

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/javascript/controllers/notifications_controller.js \
        app/views/notifications/mark_read.turbo_stream.erb \
        app/views/notifications/_notification.html.erb \
        test/system/notifications_test.rb
git commit -m "feat: mark notifications as read on click via Stimulus

Clicking a notification row sends a PATCH to mark_read_notification_path
and swaps the row in place via Turbo Stream so the read-state styling
updates without a full page reload. Clicks on inner links are not
intercepted so normal navigation still works."
```

---

## Task 10: Navbar badge with unread count

**Files:**
- Create: `app/views/shared/_notifications_badge.html.erb`
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/controllers/application_controller.rb` (helper method)
- Modify: `test/controllers/notifications_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/controllers/notifications_controller_test.rb` before the final `end`:

```ruby
  test "layout shows unread count badge when user has unread notifications" do
    WelcomeNotifier.with(record: @user).deliver(@user)
    perform_enqueued_jobs

    get notifications_path
    assert_response :success
    assert_select "[data-notifications-badge]", text: "1"
  end

  test "layout hides badge when user has no unread notifications" do
    get notifications_path
    assert_response :success
    assert_select "[data-notifications-badge]", count: 0
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/controllers/notifications_controller_test.rb -n /badge/`

Expected: FAIL — no badge element exists.

- [ ] **Step 3: Create the badge partial**

Create `app/views/shared/_notifications_badge.html.erb`:

```erb
<%# Renders a small red dot with the unread count next to the inbox link. %>
<%# Zero-count case renders nothing. %>
<% count = current_user&.notifications&.unread&.count || 0 %>
<% if count > 0 %>
  <span data-notifications-badge
        class="inline-flex items-center justify-center px-2 py-0.5 ml-1 text-xs font-bold leading-none text-white bg-red-500 rounded-full">
    <%= count > 99 ? "99+" : count %>
  </span>
<% end %>
```

- [ ] **Step 4: Add the badge and a link to the layout**

Open `app/views/layouts/application.html.erb`. Locate the navbar section (look for user avatar or logout link). Add a notifications link that includes the badge partial:

```erb
<% if user_signed_in? %>
  <%= link_to notifications_path, class: "relative inline-flex items-center text-dark-100 hover:text-white" do %>
    <%= inline_svg "icons/bell.svg", class: "w-5 h-5" %>
    <%= render "shared/notifications_badge" %>
  <% end %>
<% end %>
```

If `bell.svg` doesn't exist, create `app/assets/images/icons/bell.svg`:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.73 21a2 2 0 0 1-3.46 0"/></svg>
```

- [ ] **Step 5: Run the test**

Run: `rails test test/controllers/notifications_controller_test.rb -n /badge/`

Expected: PASS.

- [ ] **Step 6: Run the full suite**

Run: `rails test && rails test:system`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/views/shared/_notifications_badge.html.erb \
        app/views/layouts/application.html.erb \
        app/assets/images/icons/bell.svg \
        test/controllers/notifications_controller_test.rb
git commit -m "feat: navbar unread notifications badge

Small red pill showing the unread count next to a bell icon, linking
to /notifications. Zero-count renders nothing. Truncates to '99+' at
three digits."
```

---

## Task 11: Madmin resource for `Noticed::Event`

**Files:**
- Create: `app/madmin/resources/noticed_event_resource.rb`
- Modify: `config/routes/madmin.rb`
- Create: `test/controllers/madmin/noticed_events_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/madmin/noticed_events_controller_test.rb`:

```ruby
require "test_helper"

module Madmin
  class NoticedEventsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      sign_in_admin @admin
    end

    test "admin can list noticed events" do
      get madmin_noticed_events_path
      assert_response :success
    end

    test "admin can view a noticed event" do
      user = users(:one)
      WelcomeNotifier.with(record: user).deliver(user)
      perform_enqueued_jobs
      event = Noticed::Event.last

      get madmin_noticed_event_path(event)
      assert_response :success
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { admin: { email: admin.email } }
      token = admin.generate_magic_link_token
      get verify_magic_link_admins_path(token: token)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/controllers/madmin/noticed_events_controller_test.rb`

Expected: FAIL — `madmin_noticed_events_path` is not defined.

- [ ] **Step 3: Add the Madmin routes**

Open `config/routes/madmin.rb`. Inside the `namespace :madmin do` block, add before the `root` line:

```ruby
  resources :noticed_events, only: [ :index, :show ]
  resources :noticed_notifications, only: [ :index, :show ]
```

- [ ] **Step 4: Create the Madmin resource**

Create `app/madmin/resources/noticed_event_resource.rb`:

```ruby
class NoticedEventResource < Madmin::Resource
  attribute :id, form: false
  attribute :type
  attribute :record_type, form: false
  attribute :record_id, form: false
  attribute :params, form: false
  attribute :notifications_count, form: false
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.display_name(event)
    "#{event.type} (#{event.created_at.strftime('%Y-%m-%d %H:%M')})"
  end

  def self.index_attributes
    [:id, :type, :record_type, :notifications_count, :created_at]
  end

  def self.show_attributes
    [:id, :type, :record_type, :record_id, :params, :notifications_count, :created_at, :updated_at]
  end

  def self.sortable_columns
    %w[id type record_type notifications_count created_at]
  end
end
```

- [ ] **Step 5: Run the test**

Run: `rails test test/controllers/madmin/noticed_events_controller_test.rb`

Expected: PASS.

If the Madmin controllers don't exist (`Madmin::NoticedEventsController`), Madmin generates them via its dynamic resource system — check the Madmin docs. If explicit controllers are needed, create them in `app/controllers/madmin/noticed_events_controller.rb` inheriting from `Madmin::ResourceController` or the project's existing Madmin base controller.

- [ ] **Step 6: Run the full suite**

Run: `rails test`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/madmin/resources/noticed_event_resource.rb \
        config/routes/madmin.rb \
        test/controllers/madmin/noticed_events_controller_test.rb
git commit -m "feat: add Madmin resource for Noticed::Event

Read-only audit view of every notification event, sorted and filterable.
Admins can see what was sent, to whom, with what params, and how many
recipients received a given event."
```

---

## Task 12: Madmin resource for `Noticed::Notification`

**Files:**
- Create: `app/madmin/resources/noticed_notification_resource.rb`
- Create: `test/controllers/madmin/noticed_notifications_controller_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/controllers/madmin/noticed_notifications_controller_test.rb`:

```ruby
require "test_helper"

module Madmin
  class NoticedNotificationsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = admins(:one)
      sign_in_admin @admin
    end

    test "admin can list noticed notifications" do
      get madmin_noticed_notifications_path
      assert_response :success
    end

    test "admin can view a noticed notification" do
      user = users(:one)
      WelcomeNotifier.with(record: user).deliver(user)
      perform_enqueued_jobs
      notification = Noticed::Notification.last

      get madmin_noticed_notification_path(notification)
      assert_response :success
    end

    private

    def sign_in_admin(admin)
      post admins_session_path, params: { admin: { email: admin.email } }
      token = admin.generate_magic_link_token
      get verify_magic_link_admins_path(token: token)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `rails test test/controllers/madmin/noticed_notifications_controller_test.rb`

Expected: FAIL — routes exist from Task 11 but the resource class is missing.

- [ ] **Step 3: Create the Madmin resource**

Create `app/madmin/resources/noticed_notification_resource.rb`:

```ruby
class NoticedNotificationResource < Madmin::Resource
  attribute :id, form: false
  attribute :type
  attribute :event_id, form: false
  attribute :recipient_type, form: false
  attribute :recipient_id, form: false
  attribute :read_at, form: false
  attribute :seen_at, form: false
  attribute :created_at, form: false

  def self.display_name(notification)
    "#{notification.type} → #{notification.recipient_type} #{notification.recipient_id}"
  end

  def self.index_attributes
    [:id, :type, :recipient_type, :read_at, :created_at]
  end

  def self.show_attributes
    [:id, :type, :event_id, :recipient_type, :recipient_id, :read_at, :seen_at, :created_at]
  end

  def self.sortable_columns
    %w[id type recipient_type read_at created_at]
  end
end
```

- [ ] **Step 4: Run the test**

Run: `rails test test/controllers/madmin/noticed_notifications_controller_test.rb`

Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `rails test`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/madmin/resources/noticed_notification_resource.rb \
        test/controllers/madmin/noticed_notifications_controller_test.rb
git commit -m "feat: add Madmin resource for Noticed::Notification

Read-only audit view of every delivery record. Completes the
notification audit trail: Event → Notification → Recipient."
```

---

## Task 13: Hook `WelcomeNotifier` into user signup

**Files:**
- Modify: `app/controllers/sessions_controller.rb` (or the magic-link verify action — wherever a user's first session is created)
- Modify: `test/controllers/sessions_controller_test.rb`

- [ ] **Step 1: Find where users are first created**

Run: `grep -rn "User.find_or_create_by\|User.create" app/controllers/`

Locate the magic-link `verify` action (likely in `app/controllers/sessions_controller.rb`). Note the exact line where a user is persisted for the first time.

- [ ] **Step 2: Write the failing test**

Open `test/controllers/sessions_controller_test.rb`. Add:

```ruby
  test "first magic link login triggers WelcomeNotifier" do
    assert_difference -> { Noticed::Event.where(type: "WelcomeNotifier").count }, 1 do
      post session_path, params: { session: { email: "brand-new@example.com" } }
      user = User.find_by!(email: "brand-new@example.com")
      token = user.generate_magic_link_token
      get verify_magic_link_path(token: token)
      perform_enqueued_jobs
    end
  end

  test "subsequent magic link logins do not re-send WelcomeNotifier" do
    existing = users(:one)
    assert_no_difference -> { Noticed::Event.where(type: "WelcomeNotifier").count } do
      post session_path, params: { session: { email: existing.email } }
      token = existing.generate_magic_link_token
      get verify_magic_link_path(token: token)
      perform_enqueued_jobs
    end
  end
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `rails test test/controllers/sessions_controller_test.rb -n /WelcomeNotifier/`

Expected: FAIL — no notifier is being triggered.

- [ ] **Step 4: Trigger `WelcomeNotifier` on first-time user creation**

Open `app/controllers/sessions_controller.rb`. Find the line where a new user is created (likely in `create` or `verify`). After the user is persisted for the first time, add:

```ruby
WelcomeNotifier.with(record: user).deliver(user) if user.previously_new_record?
```

The exact placement depends on the controller structure. The key is to call it *only* when the user is new (not on every login).

- [ ] **Step 5: Run the test**

Run: `rails test test/controllers/sessions_controller_test.rb -n /WelcomeNotifier/`

Expected: PASS (both tests).

- [ ] **Step 6: Run the full suite**

Run: `rails test && rails test:system`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/sessions_controller.rb test/controllers/sessions_controller_test.rb
git commit -m "feat: trigger WelcomeNotifier on first user creation

The reference notifier is now exercised by the real signup flow. New
users receive a welcome notification (database + email); returning
users do not. Gives consuming apps a working end-to-end example of
the Notifier pattern."
```

---

## Task 14: Fixtures for notifications (for MigraJob-style tests later)

**Files:**
- Create: `test/fixtures/noticed_events.yml`
- Create: `test/fixtures/noticed_notifications.yml`

- [ ] **Step 1: Create `noticed_events` fixture**

Create `test/fixtures/noticed_events.yml`:

```yaml
# Hardcoded UUIDv7 strings for referential integrity.
welcome_for_user_one:
  id: 01961a2a-c0de-7000-8000-a00000000001
  type: WelcomeNotifier
  record_type: User
  record_id: 01961a2a-c0de-7000-8000-000000000001
  params:
    record: {}
  notifications_count: 1
  created_at: <%= 1.day.ago %>
  updated_at: <%= 1.day.ago %>
```

- [ ] **Step 2: Create `noticed_notifications` fixture**

Create `test/fixtures/noticed_notifications.yml`:

```yaml
welcome_user_one:
  id: 01961a2a-c0de-7000-8000-b00000000001
  type: WelcomeNotifier::Notification
  event: welcome_for_user_one
  recipient_type: User
  recipient_id: 01961a2a-c0de-7000-8000-000000000001
  read_at: ~
  seen_at: ~
  created_at: <%= 1.day.ago %>
  updated_at: <%= 1.day.ago %>
```

Note: `User` fixtures already use `01961a2a-c0de-7000-8000-000000000001` for `users(:one)` — verify by running `cat test/fixtures/users.yml | head -20` and adjust the recipient_id above to match the actual id of `users(:one)` in your fixtures.

- [ ] **Step 3: Run the test suite to verify fixtures load**

Run: `rails test test/models/user_test.rb`

Expected: PASS. Fixtures load without referential integrity errors.

- [ ] **Step 4: Commit**

```bash
git add test/fixtures/noticed_events.yml test/fixtures/noticed_notifications.yml
git commit -m "test: add fixtures for noticed events and notifications

Gives downstream tests a ready-made notification to read from without
needing to invoke a Notifier in every setup block. IDs use hardcoded
UUIDv7 strings for referential integrity per template convention."
```

---

## Task 15: README.md update (Notifications section)

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add a Features bullet**

Open `README.md`. Find the "## Features" heading. Under the "### Platform" subsection, add after the last existing bullet:

```markdown
- **Notifications** (via Noticed v2)
  - Database + email delivery out of the box
  - Live-updating inbox via Turbo Streams
  - Per-kind, per-channel user preferences
  - Ready for Slack, SMS, web/mobile push as opt-in adapters
  - Full audit trail in Madmin at `/madmin/noticed_events`
```

- [ ] **Step 2: Add a Tech Stack line**

Find the "## Tech Stack" section. Add after the "Error Tracking" line:

```markdown
- **Notifications**: [Noticed v2](https://github.com/excid3/noticed)
```

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: README Notifications section + Tech Stack entry"
```

---

## Task 16: AGENTS.md update (Notifications top-level section)

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Add a new top-level section to AGENTS.md**

Open `AGENTS.md`. After the "## Multilingual Content" section and before the "## Testing" section, insert a new section:

```markdown
## Notifications

User-facing notifications via [Noticed v2](https://github.com/excid3/noticed). Database + email delivery shipped; Slack, Twilio, Vonage, web/mobile push available as opt-in adapters when a consuming app needs them.

### Declaring a Notifier

```ruby
# app/notifiers/deal_confirmed_notifier.rb
class DealConfirmedNotifier < ApplicationNotifier
  required_params :deal

  deliver_by :database

  deliver_by :email do |config|
    config.mailer = "NotificationMailer"
    config.method = :deal_confirmed
    config.if     = ->(r) { r.wants_notification?(kind: :deal_confirmed_notifier, channel: :email) }
  end

  notification_methods do
    def message
      I18n.t("notifiers.deal_confirmed_notifier.message", title: params[:deal].title)
    end

    def url
      Rails.application.routes.url_helpers.deal_path(params[:deal])
    end
  end
end
```

Subclass `ApplicationNotifier`, not `Noticed::Event` directly — it provides the Turbo Stream broadcast hook.

### Triggering a notification

```ruby
DealConfirmedNotifier.with(deal: deal).deliver(recipient)
# → creates noticed_event + noticed_notification rows
# → renders the email via NotificationMailer#deal_confirmed (respects user preferences)
# → broadcasts a Turbo Stream prepend to [recipient, :notifications]
```

### Reading the inbox

```ruby
current_user.notifications              # has_many :notifications, through Notifiable
current_user.notifications.unread       # provided by Noticed
current_user.notifications.mark_as_read # bulk mark-read
```

### User preferences

`User#notification_preferences` is a JSON column with the shape:

```ruby
{ "welcome_notifier" => { "email" => false, "database" => true } }
```

Missing keys mean opt-in (default behavior). Preferences are checked via `user.wants_notification?(kind:, channel:)` inside each Notifier's `deliver_by :if` block.

### Live updates

Any page that renders `<%= turbo_stream_from current_user, :notifications %>` will update live when a new notification arrives. Pages without the helper are unaffected.

### Audit trail

- `/madmin/noticed_events` — every event that was triggered, with its type, record, and params
- `/madmin/noticed_notifications` — every delivery record, with recipient and read/seen state

### File structure

```
app/
├── notifiers/
│   ├── application_notifier.rb            # Base class — Turbo broadcast hook here
│   ├── welcome_notifier.rb                # Reference notifier
│   └── [domain notifiers]
├── models/concerns/
│   └── notifiable.rb                      # Recipient concern — wants_notification? helper
├── mailers/
│   └── notification_mailer.rb             # One method per notifier using :email delivery
└── views/
    ├── notification_mailer/
    │   └── [method].html.erb              # One per notifier
    └── notifications/
        ├── index.html.erb                 # Inbox
        ├── _notification.html.erb         # Row wrapper — dispatches by kind
        └── kinds/
            └── _[kind].html.erb           # Per-notifier UI partial
```

### Rule: no service-layer notification helpers

Do not wrap `Notifier.with(...).deliver(recipient)` in a service method. The Notifier class *is* the service — calling it from a controller action or model callback is the pattern. If you find yourself wanting a `NotificationService`, that's a sign the Notifier class itself should absorb the logic.
```

- [ ] **Step 2: Run the test suite one more time**

Run: `bin/ci`

Expected: PASS — this is all docs, no code change.

- [ ] **Step 3: Commit**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md Notifications top-level section

Documents the Notifier → Notification → recipient flow with concrete
code for declaring a notifier, triggering delivery, reading the inbox,
and managing user preferences. Also codifies the 'no service-layer
wrappers' rule so contributors don't reinvent it."
```

---

## Task 17: Final verification

**Files:**
- (none — verification only)

- [ ] **Step 1: Run full CI**

Run: `bin/ci`

Expected: PASS. All rubocop, all tests, all brakeman.

- [ ] **Step 2: Manual smoke test in dev**

```bash
bin/dev
```

In the browser:
1. Sign out if signed in.
2. Visit `/session/new`, enter a brand-new email, click through the magic link.
3. Verify you land somewhere signed-in.
4. Visit `/notifications` — you should see one welcome notification.
5. Visit `/` — the bell icon in the navbar should show a red `1` badge.
6. Click the notification row — it should become dimmed and the badge should disappear.
7. Visit `/madmin/noticed_events` as an admin — you should see one event row of type `WelcomeNotifier`.
8. Visit `/madmin/noticed_notifications` — you should see one notification row.

- [ ] **Step 3: Verify i18n completeness**

Run: `bundle exec i18n-tasks health`

Expected: no missing or unused keys. If there are missing keys, add them to the relevant locale file. If there are unused keys (template fixtures), that's acceptable — document why.

- [ ] **Step 4: Final commit if anything was adjusted during smoke test**

```bash
git add -u
git commit -m "chore: smoke-test fixes for notifications primitive"
```

Only needed if Step 2 or Step 3 surfaced anything. Otherwise, skip.

- [ ] **Step 5: Push and open PR (or merge to main)**

If working in a worktree / feature branch:

```bash
git push -u origin feature/notifications-noticed
gh pr create --title "feat: notifications primitive (Noticed v2)" \
             --body "$(cat <<'EOF'
## Summary

Adds user-facing notifications via Noticed v2 per `docs/specs/template-improvements.md` §1.

- Database + email delivery out of the box
- Live-updating inbox via Turbo Stream
- Per-kind, per-channel user preferences via `notification_preferences` json column
- `Notifiable` concern wraps `has_noticed_notifications` with `wants_notification?` helper
- `ApplicationNotifier` base class includes Turbo Stream broadcast
- `WelcomeNotifier` reference ships and is exercised by first-time user signup
- Madmin audit resources for `Noticed::Event` and `Noticed::Notification`
- Full i18n coverage (en + ru)
- `AGENTS.md` + `README.md` updated

## Test plan

- [x] `bin/ci` passes
- [x] New user signup triggers welcome notification end-to-end
- [x] Existing user login does not re-trigger welcome
- [x] Turbo Stream live update works in system test
- [x] Mark-as-read on click works
- [x] User preferences correctly suppress email delivery
- [x] Madmin admin can view events and notifications
- [x] `i18n-tasks health` passes

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

If working directly on main (not recommended, but possible for solo work):

```bash
# main already has the commits; nothing to do
git push origin main
```

---

## Self-review

Checking the plan against the spec (`docs/specs/template-improvements.md` §1):

**1. Spec coverage:**
- ✅ Noticed v2 installed → Task 1
- ✅ UUIDv7-patched migrations → Task 2
- ✅ `Notifiable` concern → Task 4
- ✅ User preference column → Task 3
- ✅ `wants_notification?` helper → Task 4
- ✅ `ApplicationNotifier` base class → Task 5
- ✅ `WelcomeNotifier` reference → Task 6
- ✅ `NotificationMailer` → Task 6
- ✅ Inbox UI (controller + views) → Task 7
- ✅ Turbo Stream broadcasting → Task 8
- ✅ Stimulus mark-as-read → Task 9
- ✅ Navbar badge → Task 10
- ✅ Madmin `Noticed::Event` resource → Task 11
- ✅ Madmin `Noticed::Notification` resource → Task 12
- ✅ Signup hook for welcome notifier → Task 13
- ✅ Fixtures for downstream tests → Task 14
- ✅ `README.md` update → Task 15
- ✅ `AGENTS.md` update → Task 16
- ✅ Doc housekeeping (§7 non-code) → Task 0

**2. Placeholder scan:** no TBD/TODO/"similar to Task N"/"add appropriate error handling"/etc. Every step has concrete code or a concrete action.

**3. Type consistency:**
- `WelcomeNotifier` is referenced in Tasks 6, 8, 13, 14, 15, 16 — always as `WelcomeNotifier < ApplicationNotifier`, consistent.
- `wants_notification?(kind:, channel:)` signature is consistent across Tasks 4, 6, 16.
- `Notification` partial file path (`app/views/notifications/_notification.html.erb`) is consistent across Tasks 7, 8, 9.
- `mark_read_notification_path` is consistent across Tasks 7, 9, 10.
- `notification_preferences` column is referenced consistently as a JSON column with `{ kind => { channel => bool } }` shape.

**4. Known unknowns flagged inline:**
- Task 8 Step 3 offers two approaches for Turbo Stream broadcasting (`deliver_by :action_cable` vs `after_create_commit` initializer) — the simpler one is marked as the "alternative" and should be preferred if the first doesn't cooperate.
- Task 11 Step 5 notes that Madmin may or may not auto-generate controllers for Noticed::Event — instructions to check docs and create explicit controllers if needed.
- Task 14 Step 2 notes that the recipient_id in fixtures needs to match the actual user fixture id — told to verify.

---

## Execution handoff

**Plan complete and saved to `docs/plans/2026-04-14-notifications-noticed-v2.md`.**

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Each task is small enough to fit in a single agent turn. Good for maintaining quality and catching problems early.

**2. Inline Execution** — Execute tasks in the current session using `superpowers:executing-plans`, batch execution with checkpoints for review. Faster if you trust the plan; slower to recover if a task reveals a problem.

Which approach, and do you want me to start execution now or iterate on the plan first?
