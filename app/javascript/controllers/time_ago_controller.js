import { Controller } from "@hotwired/stimulus"

const TRANSLATIONS = {
  en: {
    ago: "ago",
    just_now: "just now",
    seconds: (n) => `${n} seconds`,
    minute: "1 minute",
    minutes: (n) => `${n} minutes`,
    hour: "about 1 hour",
    hours: (n) => `about ${n} hours`,
    day: "1 day",
    days: (n) => `${n} days`,
    month: "about 1 month",
    months: (n) => `${n} months`,
  },
  ru: {
    ago: "назад",
    just_now: "только что",
    seconds: (n) => `${n} ${ruPlural(n, "секунда", "секунды", "секунд")}`,
    minute: "1 минуту",
    minutes: (n) => `${n} ${ruPlural(n, "минуту", "минуты", "минут")}`,
    hour: "около 1 часа",
    hours: (n) => `около ${n} ${ruPlural(n, "часа", "часов", "часов")}`,
    day: "1 день",
    days: (n) => `${n} ${ruPlural(n, "день", "дня", "дней")}`,
    month: "около 1 месяца",
    months: (n) => `${n} ${ruPlural(n, "месяц", "месяца", "месяцев")}`,
  },
}

function ruPlural(n, one, few, many) {
  const mod10 = n % 10
  const mod100 = n % 100
  if (mod10 === 1 && mod100 !== 11) return one
  if (mod10 >= 2 && mod10 <= 4 && !(mod100 >= 12 && mod100 <= 14)) return few
  return many
}

function formatTimeAgo(date, locale) {
  const t = TRANSLATIONS[locale] || TRANSLATIONS.en
  const seconds = Math.floor((Date.now() - date.getTime()) / 1000)

  if (seconds < 30) return t.just_now
  if (seconds < 60) return `${t.seconds(seconds)} ${t.ago}`
  if (seconds < 120) return `${t.minute} ${t.ago}`

  const minutes = Math.floor(seconds / 60)
  if (minutes < 60) return `${t.minutes(minutes)} ${t.ago}`
  if (minutes < 120) return `${t.hour} ${t.ago}`

  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${t.hours(hours)} ${t.ago}`
  if (hours < 48) return `${t.day} ${t.ago}`

  const days = Math.floor(hours / 24)
  if (days < 30) return `${t.days(days)} ${t.ago}`
  if (days < 60) return `${t.month} ${t.ago}`

  const months = Math.floor(days / 30)
  return `${t.months(months)} ${t.ago}`
}

export default class extends Controller {
  static values = { locale: { type: String, default: "en" } }

  connect() {
    this.date = new Date(this.element.getAttribute("datetime"))
    this.update()
    this.timer = setInterval(() => this.update(), 30000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    this.element.textContent = formatTimeAgo(this.date, this.localeValue)
  }
}
