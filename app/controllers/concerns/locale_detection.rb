module LocaleDetection
  extend ActiveSupport::Concern

  private

  def detect_browser_locale
    return nil unless request.headers["Accept-Language"]

    accepted = parse_accept_language(request.headers["Accept-Language"])
    enabled = Language.enabled_codes

    accepted.find { |code| enabled.include?(code) }&.to_sym
  end

  def parse_accept_language(header)
    header.to_s.split(",").filter_map { |entry|
      lang, quality = entry.strip.split(";")
      code = lang&.strip&.split("-")&.first&.downcase
      q = quality ? quality.strip.delete_prefix("q=").to_f : 1.0
      [ code, q ] if code.present?
    }.sort_by { |_, q| -q }.map(&:first).uniq
  end
end
