# Multilingual Content Standards

## Overview

User-generated content is automatically translated via LLM when teams enable multiple languages. The Mobility gem stores translations; RubyLLM handles the actual translation.

## Making a Model Translatable

1. Include the `Translatable` concern
2. Call `translatable` for each attribute with its type (`:string` or `:text`)
3. The model must `belong_to :team` (translations are team-scoped)

```ruby
class Article < ApplicationRecord
  include Translatable
  belongs_to :team
  belongs_to :user
  translatable :title, type: :string
  translatable :body, type: :text
end
```

## How It Works

### Storage: Mobility KeyValue Backend

Translations are stored in two shared polymorphic tables:
- `mobility_string_translations` - for string columns
- `mobility_text_translations` - for text columns

No per-model migration needed. You specify the type explicitly via the `type:` keyword.

### Translation Flow

1. Record is created/updated with translatable attribute changes
2. `after_commit` callback checks `previous_changes` for translatable attributes
3. Gets team's `translation_target_codes(exclude: source_locale)`
4. Bulk-enqueues `TranslateContentJob` via `perform_all_later`
5. Job calls `RubyLLM.chat(model: "gpt-4.1-nano")` with JSON prompt
6. Saves translations via `Mobility.with_locale(target_locale)` with callbacks skipped

### Reading Translations

```ruby
# Default: reads current I18n.locale, falls back to :en
article.title  # => "Hello" (if locale is :en or no translation)

# Explicit locale
Mobility.with_locale(:es) { article.title }  # => "Hola"
```

### Preventing Infinite Loops

Set `skip_translation_callbacks = true` before saving translations:

```ruby
record.skip_translation_callbacks = true
Mobility.with_locale(:es) { record.update!(title: "Manual translation") }
record.skip_translation_callbacks = false
```

## Team Language Management

- Teams have languages via `TeamLanguage` join model
- English is always required (cannot be disabled)
- Adding a language triggers `BackfillTranslationsJob` for existing content
- Removing a language soft-disables (sets `active: false`), preserving translations

## Admin Language Management

- Languages are managed globally via Madmin at `/madmin/languages`
- Admin can enable/disable languages (except English)
- `Language.enabled_codes` is cached for 5 minutes

## Locale Detection

- `Accept-Language` header is parsed in `ApplicationController`
- Matched against `Language.enabled_codes`
- Sets `I18n.locale` for the request (UI translations)
- `detected_locale` helper available in views

## Adding a New Translatable Model

1. Create migration with `team_id` foreign key
2. Include `Translatable` and call `translatable :attr, type: :string` (or `:text`)
3. Add MCP tools for parity
4. Write tests (concern handles translation queueing automatically)
