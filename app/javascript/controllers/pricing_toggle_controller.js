import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["monthlyButton", "yearlyButton", "monthlyPrices", "yearlyPrices"]

  connect() {
    this.showMonthly()
  }

  showMonthly() {
    this.monthlyPricesTarget.classList.remove("hidden")
    this.yearlyPricesTarget.classList.add("hidden")
    this.monthlyButtonTarget.classList.add("bg-accent-600", "text-white")
    this.monthlyButtonTarget.classList.remove("text-dark-400")
    this.yearlyButtonTarget.classList.remove("bg-accent-600", "text-white")
    this.yearlyButtonTarget.classList.add("text-dark-400")
  }

  showYearly() {
    this.yearlyPricesTarget.classList.remove("hidden")
    this.monthlyPricesTarget.classList.add("hidden")
    this.yearlyButtonTarget.classList.add("bg-accent-600", "text-white")
    this.yearlyButtonTarget.classList.remove("text-dark-400")
    this.monthlyButtonTarget.classList.remove("bg-accent-600", "text-white")
    this.monthlyButtonTarget.classList.add("text-dark-400")
  }
}
