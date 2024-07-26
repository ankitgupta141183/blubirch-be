CarrierWave.configure do |config|
  config.fog_provider = 'fog/aws'
  config.fog_credentials = {
    provider:              'AWS',                                                               # required
    aws_access_key_id:     Rails.application.credentials.access_key_id,           # required unless using use_iam_profile
    aws_secret_access_key: Rails.application.credentials.secret_access_key,        # required unless using use_iam_profile
    use_iam_profile:       false,                                                               # optional, defaults to false
    region:                Rails.application.credentials.aws_s3_region,     # optional, defaults to 'us-east-1'
    host:                  Rails.application.credentials.aws_s3_host_name   # optional, defaults to nil
  }
  config.fog_directory  = Rails.application.credentials.aws_bucket
  config.storage = :fog          # required
end
