# Plan 07: Locale Readiness

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** Plans 01–06 can all be merged first, or this plan can land in parallel — no code dependency on any other plan. Placed last in the order because it's trivial and can be done whenever convenient.

**Goal:** Add language-name stubs for `tg`, `uz`, `ky`, `tr`, `sr` so that consuming projects (particularly the upcoming MigraJob app) can add full locale files and have them immediately show up with human-readable names in the Madmin language picker and team language settings.

**Architecture:** Pure data. No code changes. Add new entries to the existing `languages.*` namespace in `config/locales/en.yml` and `config/locales/ru.yml`. The existing `Language.sync_from_locale_files!` mechanism picks them up automatically.

**Tech Stack:** Rails i18n, existing `Language` model.

**Prerequisites:** None beyond the template in its current state.

**Task count:** 4 tasks. This is the smallest plan in the set.

---

## File structure

**Modified:**
```
config/locales/en.yml
config/locales/ru.yml
test/models/language_test.rb
README.md                                  # tiny update — list supported language codes
```

---

## Task 1: Verify the current Language sync mechanism

Before touching anything, confirm the template's `Language` model reads language names from `config/locales/*.yml`.

- [ ] **Step 1: Read the Language model**

Run: `cat app/models/language.rb`

Look for any method like `sync_from_locale_files!`, `seed_from_i18n!`, or similar. Note how it discovers languages — whether it iterates `I18n.available_locales`, whether it reads a specific YAML key, and where it expects language names to live.

- [ ] **Step 2: Check existing locale files**

Run: `grep -r "languages:" config/locales/en.yml config/locales/ru.yml`

Note the current structure. It likely looks like:

```yaml
en:
  languages:
    en: "English"
    de: "German"
    es: "Spanish"
    fr: "French"
    ru: "Russian"
```

- [ ] **Step 3: Smoke-test the sync**

Run: `bin/rails runner 'Language.sync_from_locale_files! rescue puts "no sync method"; puts Language.all.pluck(:code, :name).to_h'`

Expected: prints the five existing codes with their names. If the output is different, adjust the approach in Task 2 to match the actual sync mechanism.

- [ ] **Step 4: No commit yet**

This is verification only. Proceed to Task 2 with the findings.

---

## Task 2: Add language-name stubs

**Files:**
- Modify: `config/locales/en.yml`
- Modify: `config/locales/ru.yml`

- [ ] **Step 1: Write the failing test**

Append to `test/models/language_test.rb`:

```ruby
  test "English locale file includes stubs for tg, uz, ky, tr, sr" do
    I18n.with_locale(:en) do
      assert_equal "Tajik",      I18n.t("languages.tg")
      assert_equal "Uzbek",      I18n.t("languages.uz")
      assert_equal "Kyrgyz",     I18n.t("languages.ky")
      assert_equal "Turkish",    I18n.t("languages.tr")
      assert_equal "Serbian",    I18n.t("languages.sr")
    end
  end

  test "Russian locale file includes stubs for tg, uz, ky, tr, sr" do
    I18n.with_locale(:ru) do
      assert_equal "Таджикский",   I18n.t("languages.tg")
      assert_equal "Узбекский",    I18n.t("languages.uz")
      assert_equal "Киргизский",   I18n.t("languages.ky")
      assert_equal "Турецкий",     I18n.t("languages.tr")
      assert_equal "Сербский",     I18n.t("languages.sr")
    end
  end
```

- [ ] **Step 2: Run to verify failure**

Run: `rails test test/models/language_test.rb -n /stubs/`

Expected: FAIL — `I18n::MissingTranslationData` for `languages.tg` (etc).

- [ ] **Step 3: Add the stubs to `config/locales/en.yml`**

Open `config/locales/en.yml`. Find the `languages:` key (likely nested under `en:`). Add the five new codes:

```yaml
en:
  languages:
    # ...existing entries...
    tg: "Tajik"
    uz: "Uzbek"
    ky: "Kyrgyz"
    tr: "Turkish"
    sr: "Serbian"
```

- [ ] **Step 4: Add the stubs to `config/locales/ru.yml`**

Open `config/locales/ru.yml`. Add the equivalent entries:

```yaml
ru:
  languages:
    # ...existing entries...
    tg: "Таджикский"
    uz: "Узбекский"
    ky: "Киргизский"
    tr: "Турецкий"
    sr: "Сербский"
```

- [ ] **Step 5: Run the test**

Run: `rails test test/models/language_test.rb -n /stubs/`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add config/locales/en.yml config/locales/ru.yml test/models/language_test.rb
git commit -m "feat: locale stubs for tg, uz, ky, tr, sr (en + ru)

Adds language-name translations so that consuming apps can ship full
locale files for these languages and have them immediately display with
human-readable names in the Madmin language picker and team settings.
No code changes — the existing Language sync mechanism picks them up."
```

---

## Task 3: Document the rule for adding more languages

**Files:**
- Modify: `AGENTS.md` (add to existing Multilingual Content section)

- [ ] **Step 1: Add a subsection**

Open `AGENTS.md`. Find the "## Multilingual Content" section. After the existing content, add:

```markdown
### Adding a New Language

To add support for a language that isn't already in `config/locales/`:

1. **Add language-name stubs** to `config/locales/en.yml` and `config/locales/ru.yml` under the `languages:` key, using the ISO 639-1 code and the localized name:
   ```yaml
   en:
     languages:
       xx: "Example Language"
   ru:
     languages:
       xx: "Пример языка"
   ```
2. **Create the full locale file** at `config/locales/xx.yml` and per-view/mailer files under `config/locales/xx/`. Follow the existing structure of `config/locales/en/` as the canonical layout.
3. **Run the language sync** to populate the `Language` model:
   ```bash
   bin/rails runner 'Language.sync_from_locale_files!'
   ```
4. **Enable the language** via Madmin at `/madmin/languages` (admin action) or per-team at `/t/:slug/languages`.
5. **Verify pluralization rules** — Russian and several Slavic languages have the `one/few/many/other` rule; Arabic has `zero/one/two/few/many/other`. Rails i18n handles these natively if the YAML file defines all the forms.

The template ships language-name stubs for `en, de, es, fr, ru` (full content) and `tg, uz, ky, tr, sr` (stubs only — add content when a consuming project needs them).

### Pluralization Example (Russian)

```yaml
ru:
  candidates:
    count:
      one:   "%{count} кандидат"
      few:   "%{count} кандидата"
      many:  "%{count} кандидатов"
      other: "%{count} кандидата"
```

Always use `t("key", count: n)` (not string interpolation) for any countable noun.
```

- [ ] **Step 2: Commit**

```bash
git add AGENTS.md
git commit -m "docs: document how to add a new language + pluralization rule"
```

---

## Task 4: README.md update + verification + PR

- [ ] **Step 1: Update README.md**

Open `README.md`. Find the Tech Stack or Features section mentioning Multilingual support. Update the supported-language list to:

```markdown
- **Multilingual**: auto-translation via LLM, locale-name stubs for `en, de, es, fr, ru` (full UI) and `tg, uz, ky, tr, sr` (stubs — add content per consuming project)
```

- [ ] **Step 2: Run i18n-tasks health**

```bash
bundle exec i18n-tasks health
```

Expected: no missing/unused keys. The new stubs should appear as valid entries.

- [ ] **Step 3: Run full CI**

Run: `bin/ci`

Expected: PASS.

- [ ] **Step 4: Commit and PR**

```bash
git add README.md
git commit -m "docs: README language list updated with new stubs"
git push -u origin feature/locale-readiness
gh pr create --title "feat: locale readiness — language stubs for tg/uz/ky/tr/sr" \
             --body "Implements docs/specs/template-improvements.md §8 per plan 07.

Adds language-name translations for Tajik, Uzbek, Kyrgyz, Turkish, and
Serbian so consuming projects can add full locale files without needing
to also add the language-name stubs. No code changes."
```

---

## Self-review

**Spec coverage** (template-improvements.md §8):
- ✅ `tg, uz, ky, tr, sr` language-name stubs in English — Task 2
- ✅ Same stubs in Russian — Task 2
- ✅ Documentation for adding new languages — Task 3
- ✅ Documentation for Russian pluralization — Task 3
- ✅ README update — Task 4

No placeholders. No type consistency concerns — this plan has no Ruby code, only YAML and Markdown.

---

## Execution handoff

This plan is small enough to execute inline in a single session without subagents. Estimated time: 15 minutes. The only risk is if `Language.sync_from_locale_files!` expects a different YAML structure than assumed; Task 1's verification step catches that before any changes land.
