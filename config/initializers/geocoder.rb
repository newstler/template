mmdb_path = Rails.root.join("db", "GeoLite2-Country.mmdb")

Geocoder.configure(
  if mmdb_path.exist?
    { ip_lookup: :geoip2, geoip2: { file: mmdb_path.to_s } }
  else
    { ip_lookup: :test, test: [] }
  end
)
