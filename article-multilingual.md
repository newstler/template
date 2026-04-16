# Your app should speak my language

I live in Spain. My phone is in English. My laptop is in English. Every device I own is in English.

And yet, half the internet has decided I speak Spanish.

## The problem

Apple is probably the worst example. I open apple.com — Spanish. App Store descriptions — Spanish. iCloud emails — Spanish. I didn't ask for any of this. Apple looked at my IP address, decided I must be Spanish, and that was that.

Google does the same. Amazon does the same. Booking.com does the same.

The logic seems straightforward: you're in Spain, so you speak Spanish. But Spain has millions of expats, tourists, remote workers. I know people who've lived here for ten years and never learned Spanish. And that's before you consider Catalonia, Basque Country, or Galicia, where people speak their regional language before Castilian.

Now imagine Switzerland with four official languages. Or India with 22.

Location tells you almost nothing about what language someone speaks.

## And you can't even fix it

Many sites don't let you change the language at all. Some hide it three clicks deep in settings. Some let you change it but reset on the next visit because the cookie expired.

My favorite: you pick English on the homepage, navigate to a product page, and it's back in Spanish. The language picker was decorative.

## The answer has existed for 30 years

Every browser sends an `Accept-Language` header with every request. It's been in HTTP since 1996. It lists the languages the user actually wants, in order of preference. Mine looks like this:

```
Accept-Language: en-US,en;q=0.9,ru;q=0.8,es;q=0.7
```

English first. Russian second. Spanish third. I set this in my OS preferences. It reflects my actual choice — not a guess based on my IP address.

Every web framework knows how to parse this. And yet most developers ignore it and reach for a GeoIP database instead.

## How I do it

In my Rails apps, on every request I match the `Accept-Language` header against the languages the app supports. If the user has saved a preference — use that. Otherwise, use the header. Fall back to the default if nothing matches.

## Beyond the UI

Rails I18n handles interface strings. Solved problem. The hard part is user-generated content. Someone writes an article in English, another user's browser says they want Spanish — what do you show?

Until recently you had two options: make users translate their own content (nobody does), or pay for human translation (slow and expensive). LLMs changed this.

I added automatic translation to my Rails template. When a team enables a new language, all existing content gets queued for translation via gpt-4.1-nano. New content gets translated on save. The cost is fractions of a cent per article.

> **Note (added later):** the model is now configured in Madmin via `Setting.translation_model`; `gpt-4.1-nano` is the current default, not a hardcoded constant.

The source language isn't hardcoded to English either. If a Spanish-speaking user writes something, Spanish becomes the source.

## The developer side

Making a model translatable is two lines:

```ruby
class Article < ApplicationRecord
  include Translatable

  translatable :title, type: :string
  translatable :body, type: :text
end
```

The concern handles detecting changes, queueing jobs, and skipping callbacks when saving translations so you don't get an infinite loop. The Mobility gem stores everything in shared polymorphic tables — no migration per model.

Teams manage their own languages through settings. Add one — existing content gets backfilled. Remove one — translations are preserved but hidden. Same operations available through MCP tools, so agents can do it too.

Your users already told you what language they speak. Their browser sends it on every request. With LLMs making translation nearly free, there's not much reason to ignore that anymore.
