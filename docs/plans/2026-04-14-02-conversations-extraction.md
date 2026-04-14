# Plan 02: Conversations Extraction from sailing_plus

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** Plan 01 (Notifications) merged to main — this plan optionally routes new-message alerts through a `NewMessageNotifier` Noticed notifier.

**Goal:** Lift the existing Conversation / ConversationMessage / ConversationParticipant machinery out of `sailing_plus` (`/Users/yurisidorov/Code/my/ruby/sailing_plus`) into the Rails template, genericize the sailing-domain bits, and add three new opt-in concerns (Turbo Stream broadcasting, `TranslatableMessage`, `ModeratableMessage`) that were missing in the sailing_plus version. Then coordinate a one-time update PR to sailing_plus so both projects share identical code.

**Architecture:** 1-to-1 file copy from sailing_plus for models / views / jobs / Stimulus controllers / tests, with a schema rewrite to make the conversation → subject relationship polymorphic (was hardcoded `adventure_id`). Views move from `teams/adventures/join_requests/` and `teams/adventures/crew_conversations/` into a new `teams/conversations/` namespace. Three new opt-in concerns plug into `ConversationMessage` via `include` — apps that don't include them get no translation, no moderation, no Turbo broadcasting.

**Tech Stack:** Rails 8, UUIDv7 PKs, Solid Cable for Turbo Streams, Noticed v2 (from Plan 01), Active Storage for attachments, Mobility for content translation (existing template infra), RubyLLM for moderation (existing).

**Prerequisites:**
- Plan 01 merged and all its tests green
- sailing_plus is readable at `/Users/yurisidorov/Code/my/ruby/sailing_plus`
- New branch or worktree for this work: `git worktree add ../template-conversations feature/conversations-extraction`

**Task count:** 21 tasks. Tasks 1–18 land the primitive. Tasks 19–20 are docs. Task 21 is the coordinated sailing_plus PR.

**Quality gate:** `bin/ci` at the end of every task. Never commit red.

---

## File structure

**New files in template:**

```
app/models/conversation.rb
app/models/conversation_message.rb
app/models/conversation_participant.rb
app/models/concerns/translatable_message.rb
app/models/concerns/moderatable_message.rb
app/controllers/teams/conversations_controller.rb
app/controllers/teams/conversations/messages_controller.rb
app/views/teams/conversations/show.html.erb
app/views/teams/conversations/_conversation_message.html.erb
app/views/teams/conversations/_message_attachments.html.erb
app/views/teams/conversations/_composer.html.erb
app/mailers/conversation_mailer.rb
app/views/conversation_mailer/new_message.html.erb
app/views/conversation_mailer/new_message.text.erb
app/views/conversation_mailer/messages_digest.html.erb
app/views/conversation_mailer/messages_digest.text.erb
app/jobs/conversation_notification_job.rb
app/jobs/conversation_digest_notification_job.rb
app/jobs/translate_message_job.rb
app/jobs/moderate_message_job.rb
app/javascript/controllers/chat_scroll_controller.js
app/javascript/controllers/chat_input_controller.js
app/madmin/resources/conversation_resource.rb
app/madmin/resources/conversation_message_resource.rb
config/locales/en/views/conversations.yml
config/locales/ru/views/conversations.yml
config/locales/en/mailers/conversation_mailer.yml
config/locales/ru/mailers/conversation_mailer.yml
db/migrate/YYYYMMDDHHMMSS_create_conversations.rb
db/migrate/YYYYMMDDHHMMSS_create_conversation_participants.rb
db/migrate/YYYYMMDDHHMMSS_create_conversation_messages.rb
db/migrate/YYYYMMDDHHMMSS_add_moderation_model_to_settings.rb
test/fixtures/conversations.yml
test/fixtures/conversation_participants.yml
test/fixtures/conversation_messages.yml
test/models/conversation_test.rb
test/models/conversation_message_test.rb
test/models/conversation_participant_test.rb
test/models/concerns/translatable_message_test.rb
test/models/concerns/moderatable_message_test.rb
test/controllers/teams/conversations_controller_test.rb
test/controllers/teams/conversations/messages_controller_test.rb
test/jobs/conversation_notification_job_test.rb
test/jobs/conversation_digest_notification_job_test.rb
test/jobs/translate_message_job_test.rb
test/jobs/moderate_message_job_test.rb
test/system/conversations_test.rb
```

**Modified files:**

```
config/routes.rb
config/routes/madmin.rb
app/models/team.rb
app/models/user.rb
app/models/setting.rb
README.md
AGENTS.md
```

**Reference source in sailing_plus** (read from `/Users/yurisidorov/Code/my/ruby/sailing_plus`):

```
app/models/conversation.rb
app/models/conversation_message.rb
app/models/conversation_participant.rb
app/controllers/teams/conversations/messages_controller.rb
app/controllers/teams/adventures/crew_conversations_controller.rb
app/views/teams/adventures/crew_conversations/show.html.erb
app/views/teams/adventures/join_requests/_conversation_message.html.erb
app/views/teams/adventures/join_requests/_message_attachments.html.erb
app/views/user_mailer/new_conversation_message.html.erb
app/views/user_mailer/new_messages_digest.html.erb
app/jobs/conversation_notification_job.rb
app/jobs/conversation_digest_notification_job.rb
app/javascript/controllers/chat_scroll_controller.js
app/javascript/controllers/chat_input_controller.js
test/models/conversation_test.rb
test/models/conversation_message_test.rb
test/models/conversation_participant_test.rb
test/controllers/teams/conversations/messages_controller_test.rb
test/controllers/teams/adventures/crew_conversations_controller_test.rb
test/jobs/conversation_notification_job_test.rb
test/jobs/conversation_digest_notification_job_test.rb
```

---

## Task 1: Create conversations table migration

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_conversations.rb`

- [x] **Step 1: Write the failing test**

Create `test/models/conversation_test.rb`:

```ruby
require "test_helper"

class ConversationTest < ActiveSupport::TestCase
  test "belongs to a team" do
    conversation = Conversation.new(team: teams(:one))
    assert_equal teams(:one), conversation.team
  end

  test "has a polymorphic subject (optional)" do
    conversation = Conversation.new(team: teams(:one))
    assert_nil conversation.subject
    assert conversation.valid?
  end

  test "has a title" do
    conversation = Conversation.new(team: teams(:one), title: "Planning")
    assert_equal "Planning", conversation.title
  end
end
```

- [x] **Step 2: Run the test to verify it fails**

Run: `rails test test/models/conversation_test.rb`

Expected: FAIL — `NameError: uninitialized constant Conversation`.

- [x] **Step 3: Create the migration**

Run: `bin/rails generate migration CreateConversations`

Edit the generated file to:

```ruby
class CreateConversations < ActiveRecord::Migration[8.1]
  def change
    create_table :conversations, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :team, null: false, foreign_key: true, type: :string
      t.references :subject, polymorphic: true, null: true, type: :string
      t.string :title
      t.timestamps
    end
  end
end
```

Note the differences from sailing_plus's migration:
- `adventure_id` → `subject_type` + `subject_id` (polymorphic, nullable)
- `subject` column (sailing_plus's free-text) → `title` (renamed to avoid collision with the polymorphic association name)

- [x] **Step 4: Run the migration**

Run: `bin/rails db:migrate`

Expected: PASS. Verify `db/schema.rb` contains the `conversations` table.

- [x] **Step 5: Commit**

```bash
git add db/migrate/*create_conversations* db/schema.rb test/models/conversation_test.rb
git commit -m "feat: create conversations table with polymorphic subject"
```

---

## Task 2: Create the Conversation model

**Files:**
- Create: `app/models/conversation.rb`
- Modify: `app/models/team.rb`

- [x] **Step 1: Create the model**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/models/conversation.rb` for reference, then create `app/models/conversation.rb`:

```ruby
class Conversation < ApplicationRecord
  belongs_to :team
  belongs_to :subject, polymorphic: true, optional: true

  has_many :conversation_participants, dependent: :destroy
  has_many :participants, through: :conversation_participants, source: :user
  has_many :conversation_messages, dependent: :destroy

  scope :chronologically, -> { order(updated_at: :desc) }

  def self.find_or_create_for(team:, subject: nil, participants: [])
    conversation = where(team: team, subject: subject).first_or_create!
    participants.each do |user|
      conversation.conversation_participants.find_or_create_by!(user: user)
    end
    conversation
  end
end
```

- [x] **Step 2: Add `has_many :conversations` to `Team`**

Open `app/models/team.rb`. Add inside the class:

```ruby
has_many :conversations, dependent: :destroy
```

- [x] **Step 3: Run the test**

Run: `rails test test/models/conversation_test.rb`

Expected: PASS.

- [x] **Step 4: Commit**

```bash
git add app/models/conversation.rb app/models/team.rb
git commit -m "feat: Conversation model with team scoping and polymorphic subject"
```

---

## Task 3: Create conversation_participants table and model

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_conversation_participants.rb`
- Create: `app/models/conversation_participant.rb`
- Create: `test/models/conversation_participant_test.rb`
- Modify: `app/models/user.rb`

- [x] **Step 1: Write the failing test**

Create `test/models/conversation_participant_test.rb`:

```ruby
require "test_helper"

class ConversationParticipantTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(team: teams(:one), title: "Test")
    @user = users(:one)
  end

  test "belongs to conversation and user" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    assert_equal @conversation, participant.conversation
    assert_equal @user, participant.user
  end

  test "is unique per conversation+user" do
    ConversationParticipant.create!(conversation: @conversation, user: @user)
    duplicate = ConversationParticipant.new(conversation: @conversation, user: @user)
    assert_not duplicate.valid?
  end

  test "mark_as_read! sets last_read_at" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    assert_nil participant.last_read_at
    participant.mark_as_read!
    assert_not_nil participant.reload.last_read_at
  end

  test "mark_as_notified! sets last_notified_at" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    participant.mark_as_notified!
    assert_not_nil participant.reload.last_notified_at
  end

  test "unread_since returns the latest of read and notified timestamps" do
    participant = ConversationParticipant.create!(conversation: @conversation, user: @user)
    time_a = 2.hours.ago
    time_b = 1.hour.ago
    participant.update!(last_read_at: time_a, last_notified_at: time_b)
    assert_in_delta time_b.to_f, participant.unread_since.to_f, 1.0
  end
end
```

- [x] **Step 2: Run the test to verify it fails**

Run: `rails test test/models/conversation_participant_test.rb`

Expected: FAIL.

- [x] **Step 3: Create the migration**

Run: `bin/rails generate migration CreateConversationParticipants`

Edit the generated file:

```ruby
class CreateConversationParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_participants, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.datetime :last_read_at
      t.datetime :last_notified_at
      t.timestamps
    end
    add_index :conversation_participants, [:conversation_id, :user_id], unique: true
  end
end
```

- [x] **Step 4: Run the migration**

Run: `bin/rails db:migrate`

- [x] **Step 5: Create the model**

Create `app/models/conversation_participant.rb`:

```ruby
class ConversationParticipant < ApplicationRecord
  belongs_to :conversation
  belongs_to :user

  validates :user_id, uniqueness: { scope: :conversation_id }

  def mark_as_read!
    update!(last_read_at: Time.current)
  end

  def mark_as_notified!
    update!(last_notified_at: Time.current)
  end

  def unread_since
    [last_read_at, last_notified_at].compact.max
  end
end
```

- [x] **Step 6: Add `has_many :conversation_participants` to `User`**

Open `app/models/user.rb`. Add:

```ruby
has_many :conversation_participants, dependent: :destroy
has_many :conversations, through: :conversation_participants
```

- [x] **Step 7: Run the test**

Run: `rails test test/models/conversation_participant_test.rb`

Expected: PASS.

- [x] **Step 8: Commit**

```bash
git add db/migrate/*conversation_participants* db/schema.rb \
        app/models/conversation_participant.rb \
        app/models/user.rb \
        test/models/conversation_participant_test.rb
git commit -m "feat: ConversationParticipant with read/notified tracking"
```

---

## Task 4: Create conversation_messages table and model

**Files:**
- Create: `db/migrate/YYYYMMDDHHMMSS_create_conversation_messages.rb`
- Create: `app/models/conversation_message.rb`
- Create: `test/models/conversation_message_test.rb`

- [x] **Step 1: Write the failing test**

Create `test/models/conversation_message_test.rb`:

```ruby
require "test_helper"

class ConversationMessageTest < ActiveSupport::TestCase
  setup do
    @conversation = Conversation.create!(team: teams(:one), title: "Test")
    @user = users(:one)
    ConversationParticipant.create!(conversation: @conversation, user: @user)
  end

  test "is valid with content only" do
    message = @conversation.conversation_messages.new(user: @user, content: "Hello")
    assert message.valid?
  end

  test "is valid with attachment only (no content)" do
    message = @conversation.conversation_messages.new(user: @user)
    file = fixture_file_upload("files/test.txt", "text/plain")
    message.attachments.attach(io: File.open(file), filename: "test.txt", content_type: "text/plain")
    assert message.valid?
  end

  test "is invalid with neither content nor attachments" do
    message = @conversation.conversation_messages.new(user: @user)
    assert_not message.valid?
    assert_includes message.errors.full_messages.join, "content"
  end

  test "touches the conversation on create" do
    original = 1.day.ago
    @conversation.update_column(:updated_at, original)
    @conversation.conversation_messages.create!(user: @user, content: "Hi")
    assert @conversation.reload.updated_at > original
  end

  test "body_translations defaults to empty hash" do
    message = @conversation.conversation_messages.create!(user: @user, content: "Hi")
    assert_equal({}, message.body_translations)
  end

  test "body_for returns the user's locale translation or falls back to content" do
    message = @conversation.conversation_messages.create!(
      user: @user,
      content: "Hi",
      body_translations: { "ru" => "Привет" }
    )

    ru_user = users(:one)
    ru_user.update!(locale: "ru")
    assert_equal "Привет", message.body_for(ru_user)

    en_user = users(:not_onboarded)
    en_user.update!(locale: "en")
    assert_equal "Hi", message.body_for(en_user)
  end
end
```

Create a tiny test fixture file: `test/fixtures/files/test.txt` with contents `hello\n`.

- [x] **Step 2: Run the test to verify it fails**

Run: `rails test test/models/conversation_message_test.rb`

Expected: FAIL.

- [x] **Step 3: Create the migration**

```ruby
class CreateConversationMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :conversation_messages, id: { type: :string, default: -> { "uuid7()" } } do |t|
      t.references :conversation, null: false, foreign_key: true, type: :string
      t.references :user, null: false, foreign_key: true, type: :string
      t.text :content
      t.json :body_translations, null: false, default: {}
      t.datetime :flagged_at
      t.string :flag_reason
      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`

- [x] **Step 4: Create the model**

Create `app/models/conversation_message.rb`:

```ruby
class ConversationMessage < ApplicationRecord
  belongs_to :conversation, touch: true
  belongs_to :user

  has_many_attached :attachments

  validate :content_or_attachments_present

  after_create_commit :broadcast_append_to_conversation
  after_create_commit :schedule_digest_notifications

  def body_for(recipient)
    return content unless recipient&.locale.present?
    body_translations[recipient.locale.to_s] || content
  end

  def visible_to?(user)
    flagged_at.blank? || user == self.user
  end

  private

  def content_or_attachments_present
    return if content.present? || attachments.attached?
    errors.add(:base, :content_or_attachments_required)
  end

  def broadcast_append_to_conversation
    broadcast_append_to conversation, target: "conversation_messages"
  end

  def schedule_digest_notifications
    ConversationDigestNotificationJob.set(wait: 2.minutes).perform_later(id)
  end
end
```

- [x] **Step 5: Run the test**

Run: `rails test test/models/conversation_message_test.rb`

Expected: PASS.

Note: the test that schedules `ConversationDigestNotificationJob` will try to enqueue a non-existent job. Add an `ActiveJob::TestHelper` include in `test_helper.rb` if not already there, and expect jobs to be enqueued. For now, create a stub:

Create `app/jobs/conversation_digest_notification_job.rb`:

```ruby
class ConversationDigestNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    # Full implementation in Task 8
  end
end
```

Re-run the test.

- [x] **Step 6: Commit**

```bash
git add db/migrate/*conversation_messages* db/schema.rb \
        app/models/conversation_message.rb \
        app/jobs/conversation_digest_notification_job.rb \
        test/models/conversation_message_test.rb \
        test/fixtures/files/test.txt
git commit -m "feat: ConversationMessage with Turbo broadcast + translation hooks"
```

---

## Task 5: Add has_many :conversation_messages shortcut on Conversation

**Files:**
- Modify: `app/models/conversation.rb`

- [x] **Step 1: Write the failing test**

Append to `test/models/conversation_test.rb`:

```ruby
  test "has many conversation_messages ordered by creation time" do
    conversation = Conversation.create!(team: teams(:one), title: "Test")
    user = users(:one)
    ConversationParticipant.create!(conversation: conversation, user: user)

    old = conversation.conversation_messages.create!(user: user, content: "old", created_at: 1.day.ago)
    new = conversation.conversation_messages.create!(user: user, content: "new")

    assert_equal [old, new], conversation.conversation_messages.chronologically.to_a
  end
```

- [x] **Step 2: Run test, observe failure**

Run: `rails test test/models/conversation_test.rb -n /chronologically/`

Expected: FAIL — `.chronologically` scope missing on conversation_messages.

- [x] **Step 3: Add the scope**

Append to `app/models/conversation_message.rb` (inside the class):

```ruby
  scope :chronologically, -> { order(created_at: :asc) }
```

- [x] **Step 4: Run test**

Run: `rails test test/models/conversation_test.rb`

Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add app/models/conversation_message.rb test/models/conversation_test.rb
git commit -m "feat: chronological scope on conversation_messages"
```

---

## Task 6: Fixtures for conversations, participants, messages

**Files:**
- Create: `test/fixtures/conversations.yml`
- Create: `test/fixtures/conversation_participants.yml`
- Create: `test/fixtures/conversation_messages.yml`

- [x] **Step 1: Create fixtures**

Create `test/fixtures/conversations.yml`:

```yaml
one:
  id: 01961a2a-c0de-7000-8000-c00000000001
  team: one
  subject_type: ~
  subject_id: ~
  title: "Team coordination"
  created_at: <%= 2.days.ago %>
  updated_at: <%= 1.hour.ago %>
```

Create `test/fixtures/conversation_participants.yml`:

```yaml
one_one:
  id: 01961a2a-c0de-7000-8000-c10000000001
  conversation: one
  user: one
  last_read_at: <%= 1.hour.ago %>
  last_notified_at: ~

one_two:
  id: 01961a2a-c0de-7000-8000-c10000000002
  conversation: one
  user: two
  last_read_at: ~
  last_notified_at: ~
```

Note: `users(:two)` must exist. If the template fixtures only have `users(:one)` and `:not_onboarded`, add a second user in `test/fixtures/users.yml` or adjust participants to use only `:one`.

Create `test/fixtures/conversation_messages.yml`:

```yaml
first:
  id: 01961a2a-c0de-7000-8000-c20000000001
  conversation: one
  user: one
  content: "Hello team"
  body_translations: {}
  created_at: <%= 2.hours.ago %>
  updated_at: <%= 2.hours.ago %>
```

- [x] **Step 2: Run full suite to verify fixtures load**

Run: `rails test`

Expected: PASS. If fixtures fail to load because of missing `users(:two)`, either add that fixture or remove the `one_two` participant.

- [x] **Step 3: Commit**

```bash
git add test/fixtures/conversations.yml test/fixtures/conversation_participants.yml test/fixtures/conversation_messages.yml
git commit -m "test: fixtures for conversations primitive"
```

---

## Task 7: Create ConversationMailer (single message + digest)

**Files:**
- Create: `app/mailers/conversation_mailer.rb`
- Create: `app/views/conversation_mailer/new_message.html.erb`
- Create: `app/views/conversation_mailer/new_message.text.erb`
- Create: `app/views/conversation_mailer/messages_digest.html.erb`
- Create: `app/views/conversation_mailer/messages_digest.text.erb`
- Create: `config/locales/en/mailers/conversation_mailer.yml`
- Create: `config/locales/ru/mailers/conversation_mailer.yml`
- Create: `test/mailers/conversation_mailer_test.rb`

- [x] **Step 1: Read the sailing_plus mailer templates for reference**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/views/user_mailer/new_conversation_message.html.erb` and `new_messages_digest.html.erb`. Note structure and i18n key usage. Use them as a starting template for the rewritten versions below.

- [x] **Step 2: Write the failing test**

Create `test/mailers/conversation_mailer_test.rb`:

```ruby
require "test_helper"

class ConversationMailerTest < ActionMailer::TestCase
  setup do
    @conversation = conversations(:one)
    @recipient = users(:one)
    @message = conversation_messages(:first)
  end

  test "new_message renders" do
    mail = ConversationMailer.with(message: @message, recipient: @recipient).new_message
    assert_equal [@recipient.email], mail.to
    assert_match @message.content, mail.body.encoded
  end

  test "messages_digest renders with up to 3 most recent messages per conversation" do
    # Create 4 messages so the digest shows top 3
    4.times { |i| @conversation.conversation_messages.create!(user: @recipient, content: "Msg #{i}") }
    mail = ConversationMailer.with(recipient: @recipient, conversations: [@conversation]).messages_digest
    assert_match "Msg 3", mail.body.encoded
  end
end
```

- [x] **Step 3: Run to verify failure**

Run: `rails test test/mailers/conversation_mailer_test.rb`

- [x] **Step 4: Create the mailer**

Create `app/mailers/conversation_mailer.rb`:

```ruby
class ConversationMailer < ApplicationMailer
  def new_message
    @message = params[:message]
    @conversation = @message.conversation
    @recipient = params[:recipient]
    mail(to: @recipient.email, subject: I18n.t("mailers.conversation_mailer.new_message.subject"))
  end

  def messages_digest
    @recipient = params[:recipient]
    @conversations = params[:conversations]
    @messages_by_conversation = @conversations.each_with_object({}) do |c, hash|
      hash[c] = c.conversation_messages.chronologically.last(3)
    end
    mail(to: @recipient.email, subject: I18n.t("mailers.conversation_mailer.messages_digest.subject"))
  end
end
```

- [x] **Step 5: Create the templates**

Create `app/views/conversation_mailer/new_message.html.erb`:

```erb
<h1><%= t(".heading") %></h1>
<p><%= t(".intro", sender: @message.user.name.presence || @message.user.email) %></p>
<blockquote><%= @message.content %></blockquote>
<p><%= link_to t(".cta"), team_conversation_url(@conversation.team.slug, @conversation) %></p>
```

Create `app/views/conversation_mailer/new_message.text.erb`:

```erb
<%= t(".heading") %>

<%= t(".intro", sender: @message.user.name.presence || @message.user.email) %>

<%= @message.content %>

<%= t(".cta") %>: <%= team_conversation_url(@conversation.team.slug, @conversation) %>
```

Create `app/views/conversation_mailer/messages_digest.html.erb`:

```erb
<h1><%= t(".heading") %></h1>
<% @messages_by_conversation.each do |conversation, messages| %>
  <h2><%= conversation.title %></h2>
  <ul>
    <% messages.each do |m| %>
      <li><strong><%= m.user.name.presence || m.user.email %>:</strong> <%= m.content %></li>
    <% end %>
  </ul>
  <p><%= link_to t(".cta"), team_conversation_url(conversation.team.slug, conversation) %></p>
<% end %>
```

Create `app/views/conversation_mailer/messages_digest.text.erb`:

```erb
<%= t(".heading") %>

<% @messages_by_conversation.each do |conversation, messages| %>
<%= conversation.title %>
<% messages.each do |m| -%>
- <%= m.user.name.presence || m.user.email %>: <%= m.content %>
<% end -%>

<%= t(".cta") %>: <%= team_conversation_url(conversation.team.slug, conversation) %>

<% end %>
```

- [x] **Step 6: Create i18n files**

Create `config/locales/en/mailers/conversation_mailer.yml`:

```yaml
en:
  mailers:
    conversation_mailer:
      new_message:
        subject: "New message in your conversation"
        heading: "New message"
        intro: "%{sender} sent you a message:"
        cta: "Reply"
      messages_digest:
        subject: "Your conversation digest"
        heading: "New messages in your conversations"
        cta: "Open conversation"
```

Create `config/locales/ru/mailers/conversation_mailer.yml`:

```yaml
ru:
  mailers:
    conversation_mailer:
      new_message:
        subject: "Новое сообщение в вашей переписке"
        heading: "Новое сообщение"
        intro: "%{sender} отправил(а) вам сообщение:"
        cta: "Ответить"
      messages_digest:
        subject: "Сводка переписки"
        heading: "Новые сообщения в ваших переписках"
        cta: "Открыть переписку"
```

- [x] **Step 7: Run the mailer test**

Run: `rails test test/mailers/conversation_mailer_test.rb`

Expected: PASS. Note the test references `team_conversation_url` which requires routes to be defined first — temporarily stub the link with a plain path or defer this test step until Task 9.

- [x] **Step 8: Commit**

```bash
git add app/mailers/conversation_mailer.rb app/views/conversation_mailer/ \
        config/locales/en/mailers/conversation_mailer.yml \
        config/locales/ru/mailers/conversation_mailer.yml \
        test/mailers/conversation_mailer_test.rb
git commit -m "feat: ConversationMailer with new_message and messages_digest"
```

---

## Task 8: Implement notification jobs

**Files:**
- Create: `app/jobs/conversation_notification_job.rb`
- Modify: `app/jobs/conversation_digest_notification_job.rb`
- Create: `test/jobs/conversation_notification_job_test.rb`
- Create: `test/jobs/conversation_digest_notification_job_test.rb`

- [x] **Step 1: Port the digest job from sailing_plus**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/jobs/conversation_digest_notification_job.rb`. Implement the template version in `app/jobs/conversation_digest_notification_job.rb`:

```ruby
class ConversationDigestNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message

    recipients = message.conversation.participants
                        .where.not(id: message.user_id)

    recipients.each do |recipient|
      participant = message.conversation.conversation_participants.find_by(user: recipient)
      next unless participant
      next if participant.last_notified_at.present? && participant.last_notified_at > 5.minutes.ago

      ConversationMailer.with(
        recipient: recipient,
        conversations: [message.conversation]
      ).messages_digest.deliver_later

      participant.mark_as_notified!
    end
  end
end
```

- [x] **Step 2: Create ConversationNotificationJob (immediate single-message email)**

Create `app/jobs/conversation_notification_job.rb`:

```ruby
class ConversationNotificationJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message

    recipients = message.conversation.participants.where.not(id: message.user_id)
    recipients.each do |recipient|
      ConversationMailer.with(message: message, recipient: recipient).new_message.deliver_later
    end
  end
end
```

- [x] **Step 3: Write job tests**

Create `test/jobs/conversation_notification_job_test.rb`:

```ruby
require "test_helper"

class ConversationNotificationJobTest < ActiveJob::TestCase
  test "sends a new-message email to each other participant" do
    message = conversation_messages(:first)
    assert_emails 1 do
      ConversationNotificationJob.perform_now(message.id)
    end
  end
end
```

Create `test/jobs/conversation_digest_notification_job_test.rb`:

```ruby
require "test_helper"

class ConversationDigestNotificationJobTest < ActiveJob::TestCase
  test "sends a digest email to each other participant" do
    message = conversation_messages(:first)
    assert_emails 1 do
      ConversationDigestNotificationJob.perform_now(message.id)
    end
  end

  test "skips recipients notified in the last 5 minutes" do
    message = conversation_messages(:first)
    participant = message.conversation.conversation_participants.where.not(user: message.user).first
    participant.update!(last_notified_at: 2.minutes.ago)

    assert_emails 0 do
      ConversationDigestNotificationJob.perform_now(message.id)
    end
  end
end
```

- [x] **Step 4: Run tests**

Run: `rails test test/jobs/`

Expected: PASS.

- [x] **Step 5: Commit**

```bash
git add app/jobs/conversation_notification_job.rb app/jobs/conversation_digest_notification_job.rb \
        test/jobs/conversation_notification_job_test.rb test/jobs/conversation_digest_notification_job_test.rb
git commit -m "feat: conversation notification jobs (single + digest)"
```

---

## Task 9: Routes and Teams::ConversationsController

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/teams/conversations_controller.rb`
- Create: `test/controllers/teams/conversations_controller_test.rb`

- [x] **Step 1: Write the failing test**

Create `test/controllers/teams/conversations_controller_test.rb`:

```ruby
require "test_helper"

class Teams::ConversationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    @user = users(:one)
    @conversation = conversations(:one)
    sign_in @user
  end

  test "GET show renders conversation for a participant" do
    get team_conversation_path(@team.slug, @conversation)
    assert_response :success
  end

  test "GET show is 404 for a non-participant" do
    other = users(:not_onboarded)
    ConversationParticipant.where(conversation: @conversation, user: other).destroy_all
    post session_path, params: { session: { email: other.email } }
    token = other.generate_magic_link_token
    get verify_magic_link_path(token: token)

    assert_raises(ActiveRecord::RecordNotFound) do
      get team_conversation_path(@team.slug, @conversation)
    end
  end

  test "GET show marks participant as read" do
    participant = ConversationParticipant.find_by!(conversation: @conversation, user: @user)
    participant.update!(last_read_at: nil)
    get team_conversation_path(@team.slug, @conversation)
    assert_not_nil participant.reload.last_read_at
  end
end
```

- [x] **Step 2: Run test, observe failure**

Run: `rails test test/controllers/teams/conversations_controller_test.rb`

- [x] **Step 3: Add routes**

Open `config/routes.rb`. Inside the `scope "/t/:team_slug"` block, add:

```ruby
    resources :conversations, controller: "teams/conversations", only: [ :show ] do
      resources :messages, controller: "teams/conversations/messages", only: [ :create ]
    end
```

- [x] **Step 4: Create the controller**

Create `app/controllers/teams/conversations_controller.rb`:

```ruby
class Teams::ConversationsController < ApplicationController
  PAGE_SIZE = 20

  before_action :authenticate_user!
  before_action :set_team
  before_action :set_conversation
  before_action :ensure_participant!

  def show
    @participant = @conversation.conversation_participants.find_by!(user: current_user)
    @participant.mark_as_read!

    @messages = scope_for_messages
    @has_older = scope_for_older_messages.any?

    respond_to do |format|
      format.html
      format.turbo_stream do
        response.set_header("X-Has-Older", @has_older.to_s)
        response.set_header("X-Oldest-Id", @messages.first&.id.to_s)
      end
    end
  end

  private

  def set_team
    @team = Team.find_by!(slug: params[:team_slug])
  end

  def set_conversation
    @conversation = @team.conversations.find(params[:id])
  end

  def ensure_participant!
    unless @conversation.conversation_participants.exists?(user: current_user)
      raise ActiveRecord::RecordNotFound
    end
  end

  def scope_for_messages
    scope = @conversation.conversation_messages.includes(:user).chronologically
    if params[:before].present?
      anchor = @conversation.conversation_messages.find(params[:before])
      scope = scope.where("created_at < ?", anchor.created_at)
    end
    scope.last(PAGE_SIZE)
  end

  def scope_for_older_messages
    return @conversation.conversation_messages.none if @messages.empty?
    @conversation.conversation_messages.where("created_at < ?", @messages.first.created_at)
  end
end
```

- [x] **Step 5: Create a stub show view (populated in Task 10)**

Create `app/views/teams/conversations/show.html.erb`:

```erb
<div class="flex flex-col h-full">
  <h1><%= @conversation.title %></h1>
  <div id="conversation_messages">
    <%= render partial: "teams/conversations/conversation_message",
               collection: @messages,
               as: :message %>
  </div>
  <%= turbo_stream_from @conversation %>
</div>
```

Create minimal partial `app/views/teams/conversations/_conversation_message.html.erb`:

```erb
<div id="<%= dom_id(message) %>" class="py-2">
  <strong><%= message.user.name.presence || message.user.email %>:</strong>
  <%= message.body_for(current_user) %>
</div>
```

- [x] **Step 6: Run test**

Run: `rails test test/controllers/teams/conversations_controller_test.rb`

Expected: PASS.

- [x] **Step 7: Commit**

```bash
git add config/routes.rb app/controllers/teams/conversations_controller.rb \
        app/views/teams/conversations/show.html.erb \
        app/views/teams/conversations/_conversation_message.html.erb \
        test/controllers/teams/conversations_controller_test.rb
git commit -m "feat: Teams::ConversationsController#show with participant guard"
```

---

## Task 10: Teams::Conversations::MessagesController#create

**Files:**
- Create: `app/controllers/teams/conversations/messages_controller.rb`
- Create: `test/controllers/teams/conversations/messages_controller_test.rb`

- [x] **Step 1: Write the failing test**

Create `test/controllers/teams/conversations/messages_controller_test.rb`:

```ruby
require "test_helper"

class Teams::Conversations::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @team = teams(:one)
    @user = users(:one)
    @conversation = conversations(:one)
    sign_in @user
  end

  test "POST creates a message with content" do
    assert_difference -> { @conversation.conversation_messages.count }, 1 do
      post team_conversation_messages_path(@team.slug, @conversation),
           params: { conversation_message: { content: "Hello world" } }
    end
    assert_redirected_to team_conversation_path(@team.slug, @conversation)
  end

  test "POST with attachments only" do
    file = fixture_file_upload("files/test.txt", "text/plain")
    assert_difference -> { @conversation.conversation_messages.count }, 1 do
      post team_conversation_messages_path(@team.slug, @conversation),
           params: { conversation_message: { attachments: [file] } }
    end
  end

  test "POST with neither content nor attachments returns unprocessable_entity" do
    post team_conversation_messages_path(@team.slug, @conversation),
         params: { conversation_message: { content: "" } }
    assert_response :unprocessable_entity
  end

  test "POST by non-participant is 404" do
    other = users(:not_onboarded)
    ConversationParticipant.where(conversation: @conversation, user: other).destroy_all
    delete session_path
    post session_path, params: { session: { email: other.email } }
    token = other.generate_magic_link_token
    get verify_magic_link_path(token: token)

    assert_raises(ActiveRecord::RecordNotFound) do
      post team_conversation_messages_path(@team.slug, @conversation),
           params: { conversation_message: { content: "Hi" } }
    end
  end
end
```

- [x] **Step 2: Run test, observe failure**

Run: `rails test test/controllers/teams/conversations/messages_controller_test.rb`

- [x] **Step 3: Create the controller**

Create `app/controllers/teams/conversations/messages_controller.rb`:

```ruby
class Teams::Conversations::MessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_team
  before_action :set_conversation
  before_action :ensure_participant!

  def create
    @message = @conversation.conversation_messages.new(message_params)
    @message.user = current_user

    if @message.save
      redirect_to team_conversation_path(@team.slug, @conversation)
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_team
    @team = Team.find_by!(slug: params[:team_slug])
  end

  def set_conversation
    @conversation = @team.conversations.find(params[:conversation_id])
  end

  def ensure_participant!
    unless @conversation.conversation_participants.exists?(user: current_user)
      raise ActiveRecord::RecordNotFound
    end
  end

  def message_params
    params.require(:conversation_message).permit(:content, attachments: [])
  end
end
```

- [x] **Step 4: Run test**

Run: `rails test test/controllers/teams/conversations/messages_controller_test.rb`

Expected: PASS (the `unprocessable_entity` test may need a `new.html.erb` template — create a minimal stub if needed).

- [x] **Step 5: Commit**

```bash
git add app/controllers/teams/conversations/messages_controller.rb \
        test/controllers/teams/conversations/messages_controller_test.rb
git commit -m "feat: Teams::Conversations::MessagesController#create"
```

---

## Task 11: Port views and Stimulus controllers from sailing_plus

**Files:**
- Modify: `app/views/teams/conversations/show.html.erb`
- Modify: `app/views/teams/conversations/_conversation_message.html.erb`
- Create: `app/views/teams/conversations/_message_attachments.html.erb`
- Create: `app/views/teams/conversations/_composer.html.erb`
- Create: `app/javascript/controllers/chat_scroll_controller.js`
- Create: `app/javascript/controllers/chat_input_controller.js`
- Create: `config/locales/en/views/conversations.yml`
- Create: `config/locales/ru/views/conversations.yml`

- [ ] **Step 1: Port Stimulus controllers verbatim**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/javascript/controllers/chat_scroll_controller.js`, copy to `app/javascript/controllers/chat_scroll_controller.js`. Review for any sailing-specific comments or class names, remove them, keep the logic.

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/javascript/controllers/chat_input_controller.js`, copy to `app/javascript/controllers/chat_input_controller.js`. Same review.

- [ ] **Step 2: Port attachments partial**

Read `/Users/yurisidorov/Code/my/ruby/sailing_plus/app/views/teams/adventures/join_requests/_message_attachments.html.erb`. Copy to `app/views/teams/conversations/_message_attachments.html.erb`, replacing any "crew" or "adventure" references with generic language (the partial itself should be mostly domain-neutral).

- [ ] **Step 3: Port and flesh out conversation_message partial**

Replace `app/views/teams/conversations/_conversation_message.html.erb` with the full version from sailing_plus (`_conversation_message.html.erb`), updating:
- `m.user.name.presence` references stay the same
- Any Adventure-specific avatar logic → use `@user.avatar` or a generic fallback
- Keep left/right alignment by sender

- [ ] **Step 4: Create composer partial**

Create `app/views/teams/conversations/_composer.html.erb`:

```erb
<%= form_with model: [@team, @conversation, ConversationMessage.new],
              url: team_conversation_messages_path(@team.slug, @conversation),
              data: { controller: "chat-input" } do |f| %>
  <div class="flex gap-2">
    <%= f.text_area :content,
                    rows: 1,
                    placeholder: t(".placeholder"),
                    data: { "chat-input-target": "textarea",
                            action: "keydown->chat-input#handleKeydown input->chat-input#resize" },
                    class: "flex-1 bg-dark-800 rounded p-2" %>
    <%= f.file_field :attachments, multiple: true,
                                    data: { "chat-input-target": "fileInput" } %>
    <%= f.submit t(".send"),
                 data: { "chat-input-target": "submit" },
                 class: "px-4 py-2 bg-accent-500 text-white rounded" %>
  </div>
<% end %>
```

- [ ] **Step 5: Rewrite the show view properly**

Replace `app/views/teams/conversations/show.html.erb`:

```erb
<% content_for :title, @conversation.title %>

<div class="flex flex-col h-full"
     data-controller="chat-scroll"
     data-chat-scroll-oldest-id-value="<%= @messages.first&.id %>"
     data-chat-scroll-has-older-value="<%= @has_older %>">
  <header class="flex items-center justify-between p-4 border-b border-dark-700">
    <h1 class="text-lg font-semibold"><%= @conversation.title %></h1>
  </header>

  <div id="conversation_messages"
       data-chat-scroll-target="container"
       class="flex-1 overflow-y-auto p-4 space-y-2">
    <%= turbo_stream_from @conversation %>
    <%= render partial: "teams/conversations/conversation_message",
               collection: @messages,
               as: :message %>
  </div>

  <div class="p-4 border-t border-dark-700">
    <%= render "teams/conversations/composer" %>
  </div>
</div>
```

- [ ] **Step 6: Create i18n files**

Create `config/locales/en/views/conversations.yml`:

```yaml
en:
  teams:
    conversations:
      show:
        title: "Conversation"
      composer:
        placeholder: "Write a message..."
        send: "Send"
```

Create `config/locales/ru/views/conversations.yml`:

```yaml
ru:
  teams:
    conversations:
      show:
        title: "Переписка"
      composer:
        placeholder: "Напишите сообщение..."
        send: "Отправить"
```

- [ ] **Step 7: Run all tests**

Run: `rails test`

Expected: PASS. If the controller tests fail due to missing view references, adjust the views to match.

- [ ] **Step 8: Commit**

```bash
git add app/views/teams/conversations/ \
        app/javascript/controllers/chat_scroll_controller.js \
        app/javascript/controllers/chat_input_controller.js \
        config/locales/en/views/conversations.yml \
        config/locales/ru/views/conversations.yml
git commit -m "feat: port conversation views and Stimulus controllers from sailing_plus"
```

---

## Task 12: Add TranslatableMessage concern

**Files:**
- Create: `app/models/concerns/translatable_message.rb`
- Create: `app/jobs/translate_message_job.rb`
- Create: `test/models/concerns/translatable_message_test.rb`
- Create: `test/jobs/translate_message_job_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/models/concerns/translatable_message_test.rb`:

```ruby
require "test_helper"

class TranslatableMessageTest < ActiveSupport::TestCase
  class TestMessage < ConversationMessage
    include TranslatableMessage
  end

  test "enqueues TranslateMessageJob after create" do
    conversation = conversations(:one)
    user = users(:one)
    assert_enqueued_with(job: TranslateMessageJob) do
      TestMessage.create!(conversation: conversation, user: user, content: "Hello")
    end
  end
end
```

- [ ] **Step 2: Run test, observe failure**

Run: `rails test test/models/concerns/translatable_message_test.rb`

- [ ] **Step 3: Create the concern**

Create `app/models/concerns/translatable_message.rb`:

```ruby
module TranslatableMessage
  extend ActiveSupport::Concern

  included do
    after_create_commit :enqueue_translation
  end

  private

  def enqueue_translation
    TranslateMessageJob.perform_later(id)
  end
end
```

- [ ] **Step 4: Create the job**

Create `app/jobs/translate_message_job.rb`:

```ruby
class TranslateMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message
    return if message.content.blank?

    target_locales = message.conversation.participants
                            .where.not(id: message.user_id)
                            .pluck(:locale)
                            .compact
                            .uniq

    return if target_locales.empty?

    model = Setting.translation_model
    return unless model

    translations = {}
    target_locales.each do |locale|
      prompt = "Translate the following text to #{locale}. Respond with only the translation, no other text.\n\n#{message.content}"
      response = RubyLLM.chat(model: model).ask(prompt)
      translations[locale.to_s] = response.content.strip
    end

    message.update_columns(body_translations: translations)
  end
end
```

- [ ] **Step 5: Create job test**

Create `test/jobs/translate_message_job_test.rb`:

```ruby
require "test_helper"

class TranslateMessageJobTest < ActiveJob::TestCase
  test "no-op when content is blank" do
    message = conversation_messages(:first)
    message.update!(content: nil)
    TranslateMessageJob.perform_now(message.id)
    assert_equal({}, message.reload.body_translations)
  end

  test "no-op when no translation model is configured" do
    Setting.any_instance.stubs(:translation_model).returns(nil)
    message = conversation_messages(:first)
    TranslateMessageJob.perform_now(message.id)
    assert_equal({}, message.reload.body_translations)
  end
end
```

Note: these tests avoid the LLM call entirely. A full integration test would stub RubyLLM; that's out of scope for this plan.

- [ ] **Step 6: Run tests**

Run: `rails test test/models/concerns/translatable_message_test.rb test/jobs/translate_message_job_test.rb`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/models/concerns/translatable_message.rb \
        app/jobs/translate_message_job.rb \
        test/models/concerns/translatable_message_test.rb \
        test/jobs/translate_message_job_test.rb
git commit -m "feat: TranslatableMessage opt-in concern with LLM translation job"
```

---

## Task 13: Add ModeratableMessage concern and Setting.moderation_model

**Files:**
- Create: `app/models/concerns/moderatable_message.rb`
- Create: `app/jobs/moderate_message_job.rb`
- Modify: `app/models/setting.rb`
- Create: `db/migrate/YYYYMMDDHHMMSS_add_moderation_model_to_settings.rb`
- Create: `test/models/concerns/moderatable_message_test.rb`
- Create: `test/jobs/moderate_message_job_test.rb`

- [ ] **Step 1: Add moderation_model column to settings**

```ruby
class AddModerationModelToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :moderation_model, :string
  end
end
```

Run: `bin/rails db:migrate`

Then open `app/models/setting.rb` and add `:moderation_model` to `ALLOWED_KEYS` and create a class reader:

```ruby
ALLOWED_KEYS = %i[
  default_model
  ...
  moderation_model
  translation_model
  ...
].freeze

def self.moderation_model
  get(:moderation_model).presence
end
```

- [ ] **Step 2: Create the concern**

Create `app/models/concerns/moderatable_message.rb`:

```ruby
module ModeratableMessage
  extend ActiveSupport::Concern

  DEFAULT_PATTERNS = [
    /\b\+?\d[\d\s\-().]{7,}\b/,                    # E.164-ish phones
    /\b[\w.+-]+@[\w.-]+\.[a-z]{2,}\b/i,            # emails
    /@\w{3,}/,                                      # @handles
    %r{(?:wa|whatsapp|t|telegram|tg|viber)\.me/\S+}i
  ].freeze

  extend ActiveSupport::Concern

  class_methods do
    def moderation_patterns
      DEFAULT_PATTERNS
    end
  end

  included do
    after_create_commit :enqueue_moderation
  end

  private

  def enqueue_moderation
    ModerateMessageJob.perform_later(id)
  end
end
```

- [ ] **Step 3: Create the job**

Create `app/jobs/moderate_message_job.rb`:

```ruby
class ModerateMessageJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = ConversationMessage.find_by(id: message_id)
    return unless message
    return if message.content.blank?

    patterns = message.class.moderation_patterns
    pattern_hit = patterns.find { |p| message.content.match?(p) }
    if pattern_hit
      message.update_columns(flagged_at: Time.current, flag_reason: "pattern_match:#{pattern_hit.source[0, 50]}")
      return
    end

    model = Setting.moderation_model
    return unless model

    prompt = <<~PROMPT
      Does the following message attempt to share off-platform contact information
      (phone, email, messenger handle, or URL)? Reply with JSON: {"flagged": bool, "reason": string}

      Message:
      #{message.content}
    PROMPT

    response = RubyLLM.chat(model: model).ask(prompt)
    parsed = JSON.parse(response.content) rescue nil
    return unless parsed.is_a?(Hash) && parsed["flagged"] == true

    message.update_columns(flagged_at: Time.current, flag_reason: "llm:#{parsed['reason']}")
  end
end
```

- [ ] **Step 4: Write tests**

Create `test/models/concerns/moderatable_message_test.rb`:

```ruby
require "test_helper"

class ModeratableMessageTest < ActiveSupport::TestCase
  class TestMessage < ConversationMessage
    include ModeratableMessage
  end

  test "enqueues ModerateMessageJob after create" do
    conversation = conversations(:one)
    user = users(:one)
    assert_enqueued_with(job: ModerateMessageJob) do
      TestMessage.create!(conversation: conversation, user: user, content: "Hi")
    end
  end
end
```

Create `test/jobs/moderate_message_job_test.rb`:

```ruby
require "test_helper"

class ModerateMessageJobTest < ActiveJob::TestCase
  setup { @message = conversation_messages(:first) }

  test "regex flags an email" do
    @message.update!(content: "reach me at john@example.com")
    ModerateMessageJob.perform_now(@message.id)
    assert @message.reload.flagged_at.present?
  end

  test "regex flags a phone number" do
    @message.update!(content: "call me +7 925 123 45 67")
    ModerateMessageJob.perform_now(@message.id)
    assert @message.reload.flagged_at.present?
  end

  test "clean content is not flagged" do
    @message.update!(content: "Looking forward to working together")
    ModerateMessageJob.perform_now(@message.id)
    assert_nil @message.reload.flagged_at
  end
end
```

- [ ] **Step 5: Run tests**

Run: `rails test test/models/concerns/moderatable_message_test.rb test/jobs/moderate_message_job_test.rb`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/concerns/moderatable_message.rb app/jobs/moderate_message_job.rb \
        app/models/setting.rb db/migrate/*moderation_model* db/schema.rb \
        test/models/concerns/moderatable_message_test.rb \
        test/jobs/moderate_message_job_test.rb
git commit -m "feat: ModeratableMessage opt-in concern with regex + LLM moderation"
```

---

## Task 14: Madmin resources for Conversation and ConversationMessage

**Files:**
- Create: `app/madmin/resources/conversation_resource.rb`
- Create: `app/madmin/resources/conversation_message_resource.rb`
- Modify: `config/routes/madmin.rb`

- [ ] **Step 1: Add routes**

Open `config/routes/madmin.rb`. Inside the `namespace :madmin do` block, add:

```ruby
resources :conversations
resources :conversation_messages
```

- [ ] **Step 2: Create the Conversation resource**

Create `app/madmin/resources/conversation_resource.rb`:

```ruby
class ConversationResource < Madmin::Resource
  attribute :id, form: false
  attribute :team
  attribute :subject_type, form: false
  attribute :subject_id, form: false
  attribute :title
  attribute :created_at, form: false
  attribute :updated_at, form: false

  def self.index_attributes
    [:id, :team, :title, :created_at]
  end

  def self.sortable_columns
    %w[id title created_at updated_at]
  end
end
```

- [ ] **Step 3: Create the ConversationMessage resource**

Create `app/madmin/resources/conversation_message_resource.rb`:

```ruby
class ConversationMessageResource < Madmin::Resource
  attribute :id, form: false
  attribute :conversation
  attribute :user
  attribute :content
  attribute :flagged_at, form: false
  attribute :flag_reason, form: false
  attribute :created_at, form: false

  def self.index_attributes
    [:id, :conversation, :user, :flagged_at, :created_at]
  end

  def self.sortable_columns
    %w[id created_at flagged_at]
  end
end
```

- [ ] **Step 4: Commit**

```bash
git add app/madmin/resources/conversation_resource.rb \
        app/madmin/resources/conversation_message_resource.rb \
        config/routes/madmin.rb
git commit -m "feat: Madmin resources for Conversation and ConversationMessage"
```

---

## Task 15: System test for end-to-end flow

**Files:**
- Create: `test/system/conversations_test.rb`

- [ ] **Step 1: Create the system test**

```ruby
require "application_system_test_case"

class ConversationsTest < ApplicationSystemTestCase
  setup do
    @team = teams(:one)
    @conversation = conversations(:one)
    @user = users(:one)
  end

  test "a participant can view and post a message" do
    sign_in_as @user
    visit team_conversation_path(@team.slug, @conversation)

    assert_selector "#conversation_messages"

    fill_in "conversation_message[content]", with: "Hello system test"
    click_on I18n.t("teams.conversations.composer.send")

    assert_selector "div", text: "Hello system test", wait: 5
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

- [ ] **Step 2: Run the test**

Run: `rails test:system test/system/conversations_test.rb`

Expected: PASS. Adjust selectors and button text if the actual view differs.

- [ ] **Step 3: Commit**

```bash
git add test/system/conversations_test.rb
git commit -m "test: system test for conversation show + post"
```

---

## Task 16: Verify Turbo Stream broadcasting end-to-end

The `broadcast_append_to` hook was added in Task 4 and the `<%= turbo_stream_from @conversation %>` tag was added in Task 11. Verify the full path works.

- [ ] **Step 1: Extend the system test**

Append to `test/system/conversations_test.rb`:

```ruby
  test "new message from another user appears live via Turbo Stream" do
    sign_in_as @user
    visit team_conversation_path(@team.slug, @conversation)

    other = users(:not_onboarded)
    ConversationParticipant.find_or_create_by!(conversation: @conversation, user: other)

    @conversation.conversation_messages.create!(user: other, content: "Live update")

    assert_selector "div", text: "Live update", wait: 5
  end
```

- [ ] **Step 2: Run**

Run: `rails test:system test/system/conversations_test.rb`

Expected: PASS. If the test hangs, verify `turbo_stream_from` is in the view and Solid Cable is configured.

- [ ] **Step 3: Commit**

```bash
git add test/system/conversations_test.rb
git commit -m "test: verify Turbo Stream live updates for new messages"
```

---

## Task 17: README.md update

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Add Features bullet**

Under `## Features` → `### Platform`, add:

```markdown
- **Team Messaging** (Conversations)
  - Team-scoped person-to-person chat with attachments
  - Live updates via Turbo Streams
  - Opt-in message translation (`TranslatableMessage` concern)
  - Opt-in content moderation (`ModeratableMessage` concern)
  - Email digests grouped by conversation
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README Conversations section"
```

---

## Task 18: AGENTS.md update

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Add Conversations top-level section**

Insert after the "## Notifications" section from Plan 01:

```markdown
## Conversations

Team-scoped person-to-person messaging at `/t/:slug/conversations/:id`. Distinct from RubyLLM AI chat (`/chats`), which is user↔LLM.

### Models

- `Conversation` — belongs to `Team`, optional polymorphic `subject` (e.g. a `Deal`, `Request`, or `nil` for team-general)
- `ConversationParticipant` — join model with `last_read_at` / `last_notified_at`
- `ConversationMessage` — `content` (nullable, allows attachment-only), `body_translations` JSON, `flagged_at`, `flag_reason`, Active Storage `attachments`

### Creating a conversation

```ruby
conversation = Conversation.find_or_create_for(
  team: team,
  subject: deal,
  participants: [agency_user, employer_user]
)
```

### Opt-in concerns

```ruby
class ConversationMessage < ApplicationRecord
  include TranslatableMessage   # auto-translate content to each participant's locale
  include ModeratableMessage    # regex + LLM moderation for contact-leak detection
end
```

Both concerns are opt-in because they require configured models (`Setting.translation_model`, `Setting.moderation_model`). Apps that don't need them simply don't include them.

### Live updates

`<%= turbo_stream_from @conversation %>` in the view enables live updates. Every new `ConversationMessage` is appended to `#conversation_messages` automatically via `after_create_commit :broadcast_append_to_conversation`.

### Read tracking

`ConversationParticipant#mark_as_read!` updates `last_read_at`. Read by `Conversation#unread_for(user)` to render an unread-count badge.
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md Conversations section"
```

---

## Task 19: Final CI + manual smoke test

- [ ] **Step 1: Run full CI**

Run: `bin/ci`

Expected: PASS.

- [ ] **Step 2: Smoke-test in dev**

```bash
bin/dev
```

Sign in, create a team with a second member, visit `/t/:slug/conversations/:id` for a seeded conversation, post a message, verify it appears live.

- [ ] **Step 3: Verify i18n**

Run: `bundle exec i18n-tasks health`

Expected: no missing keys.

- [ ] **Step 4: Commit any smoke-test fixes**

```bash
git add -u && git commit -m "chore: smoke-test fixes for conversations"
```

---

## Task 20: Coordinated sailing_plus update

This task is performed in the `sailing_plus` repository, NOT the template. It converts sailing_plus to use the new shared code from the template.

- [ ] **Step 1: In sailing_plus, pull the template merge**

```bash
cd /Users/yurisidorov/Code/my/ruby/sailing_plus
git fetch template
git merge template/main
```

- [ ] **Step 2: Resolve conflicts**

Expect conflicts in:
- `app/models/conversation.rb` (template version has polymorphic subject; sailing_plus has adventure_id)
- `app/models/conversation_message.rb` (template version has opt-in concerns + broadcasting)
- `app/controllers/teams/conversations/messages_controller.rb`
- `app/views/teams/adventures/crew_conversations/show.html.erb`
- `app/views/teams/adventures/join_requests/_conversation_message.html.erb`
- `app/javascript/controllers/chat_scroll_controller.js`
- `app/javascript/controllers/chat_input_controller.js`

Accept the template version in every conflict.

- [ ] **Step 3: Migrate `adventure_id` to polymorphic subject**

Create a new migration in sailing_plus:

```ruby
class MigrateConversationsToPolymorphicSubject < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE conversations
      SET subject_type = 'Adventure', subject_id = adventure_id
      WHERE adventure_id IS NOT NULL
    SQL
    remove_reference :conversations, :adventure
  end

  def down
    add_reference :conversations, :adventure, foreign_key: true, type: :string
    execute <<~SQL
      UPDATE conversations
      SET adventure_id = subject_id
      WHERE subject_type = 'Adventure'
    SQL
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Rename `subject` column to `title`**

```ruby
class RenameConversationSubjectToTitle < ActiveRecord::Migration[8.1]
  def change
    rename_column :conversations, :subject, :title
  end
end
```

- [ ] **Step 5: Move sailing-specific views**

Move `app/views/teams/adventures/crew_conversations/show.html.erb` → `app/views/teams/conversations/show.html.erb`. Delete the now-duplicate template version that was merged in.

- [ ] **Step 6: Update `CrewAssignment#ensure_conversation!`**

Whatever sailing_plus uses to find-or-create a conversation for a crew assignment: replace its body with a call to `Conversation.find_or_create_for(team: ..., subject: crew_assignment, participants: [...])`.

- [ ] **Step 7: Run sailing_plus tests**

Run: `rails test` in sailing_plus

Expected: PASS. Fix any lingering references to `conversation.adventure_id` or the old view paths.

- [ ] **Step 8: Commit and PR**

```bash
git add -A
git commit -m "chore: adopt shared conversations primitive from template

Template now owns Conversation/ConversationMessage/ConversationParticipant.
This commit migrates sailing_plus to the new polymorphic subject shape
and drops the old adventure_id column."
git push -u origin feature/adopt-template-conversations
gh pr create --title "Adopt shared conversations primitive from template" --body "See docs/plans/2026-04-14-02-conversations-extraction.md Task 20 in template repo."
```

---

## Task 21: Final verification and PR (in template repo)

- [ ] **Step 1: Run full CI in template**

Run: `bin/ci`

- [ ] **Step 2: Open template PR**

```bash
git push -u origin feature/conversations-extraction
gh pr create --title "feat: Conversations primitive extracted from sailing_plus" \
             --body "Implements docs/specs/template-improvements.md §2 per plan docs/plans/2026-04-14-02-conversations-extraction.md. Coordinated sailing_plus PR at <link>."
```

---

## Self-review

**Spec coverage** (template-improvements.md §2):
- ✅ Models extracted with polymorphic subject — Tasks 1–4
- ✅ Schema columns for opt-in translation and moderation — Task 4
- ✅ TranslatableMessage concern — Task 12
- ✅ ModeratableMessage concern — Task 13
- ✅ Turbo Stream broadcast on new message — Task 4 + verification in Task 16
- ✅ Stimulus controllers ported — Task 11
- ✅ Views genericized and relocated — Task 11
- ✅ Mailer (single + digest) — Task 7
- ✅ Notification jobs — Task 8
- ✅ Madmin resources — Task 14
- ✅ README + AGENTS updates — Tasks 17–18
- ✅ Coordinated sailing_plus update — Task 20

**Placeholders:** none.

**Type consistency:** `Conversation`, `ConversationMessage`, `ConversationParticipant` consistent across all tasks. `body_translations` JSON shape (`{locale => string}`) consistent between model, concern, job, and view. `mark_as_read!` signature unchanged.

---

## Execution handoff

Plan complete. Two execution options — same as Plan 01. Recommend subagent-driven for fresh context per task.
