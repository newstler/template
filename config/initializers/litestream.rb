# Litestream credentials are loaded from Setting via config/initializers/settings.rb
#
# Configure additional Litestream options below if needed.

Rails.application.configure do
  # Replica-specific region. Set the bucket's region. Only used for AWS S3 & Backblaze B2.
  # config.litestream.replica_region = "us-east-1"
  #
  # Replica-specific endpoint. Set the endpoint URL of the S3-compatible service. Only required for non-AWS services.
  # config.litestream.replica_endpoint = "endpoint.your-objectstorage.com"
end
