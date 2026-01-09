# Use this hook to configure the litestream-ruby gem.
# Litestream provides SQLite replication to S3-compatible storage.
#
# Configuration is stored in Rails encrypted credentials.
# To view/edit: rails credentials:edit --environment development
#
# Required structure:
# litestream:
#   replica_bucket: your-bucket-name
#   replica_key_id: YOUR_AWS_KEY_ID
#   replica_access_key: YOUR_AWS_SECRET_KEY

Rails.application.configure do
  # Configure Litestream through Rails encrypted credentials
  litestream_credentials = Rails.application.credentials.litestream

  config.litestream.replica_bucket = litestream_credentials&.replica_bucket
  config.litestream.replica_key_id = litestream_credentials&.replica_key_id
  config.litestream.replica_access_key = litestream_credentials&.replica_access_key

  # Replica-specific bucket location. This will be your bucket's URL without the `https://` prefix.
  # For example, if you used DigitalOcean Spaces, your bucket URL could look like:
  #
  #   https://myapp.fra1.digitaloceanspaces.com
  #
  # And so you should set your `replica_bucket` to:
  #
  #   myapp.fra1.digitaloceanspaces.com
  #
  # config.litestream.replica_bucket = litestream_credentials&.replica_bucket
  #
  # Replica-specific authentication key. Litestream needs authentication credentials to access your storage provider bucket.
  # config.litestream.replica_key_id = litestream_credentials&.replica_key_id
  #
  # Replica-specific secret key. Litestream needs authentication credentials to access your storage provider bucket.
  # config.litestream.replica_access_key = litestream_credentials&.replica_access_key
  #
  # Replica-specific region. Set the bucket’s region. Only used for AWS S3 & Backblaze B2.
  # config.litestream.replica_region = "us-east-1"
  #
  # Replica-specific endpoint. Set the endpoint URL of the S3-compatible service. Only required for non-AWS services.
  # config.litestream.replica_endpoint = "endpoint.your-objectstorage.com"

  # Configure the default Litestream config path
  # config.config_path = Rails.root.join("config", "litestream.yml")

  # Configure the Litestream dashboard
  #
  # Set the default base controller class
  # config.litestream.base_controller_class = "MyApplicationController"
  #
  # Set authentication credentials for Litestream dashboard
  # config.litestream.username = litestream_credentials&.username
  # config.litestream.password = litestream_credentials&.password
end
