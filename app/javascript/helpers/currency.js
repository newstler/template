const CURRENCY_SYMBOLS = {
  USD: "$", EUR: "€", GBP: "£", CHF: "CHF", JPY: "¥", CNY: "¥",
  KRW: "₩", INR: "₹", RUB: "₽", UAH: "₴", TRY: "₺", PLN: "zł",
  SEK: "kr", NOK: "kr", DKK: "kr", CZK: "Kč", HUF: "Ft", RON: "lei",
  BRL: "R$", THB: "฿", ILS: "₪", PHP: "₱", MXN: "$", AUD: "A$",
  CAD: "C$", NZD: "NZ$", SGD: "S$", HKD: "HK$", ZAR: "R",
}

export function currencySymbol(code) {
  return CURRENCY_SYMBOLS[code] || code
}
