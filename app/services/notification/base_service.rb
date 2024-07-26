# frozen_string_literal: true

module Notification
  class BaseService
    attr_accessor :recipient, :custom_data, :notification_name, :bcc_recipient
  
    def trigger_api_sync(request_payload = nil, url = 'notifications/trigger_notification')
      begin
        request_payload ||= payload
        url = "#{Rails.application.credentials.rule_engine_host}/api/v1/#{url}"
        req_headers = headers
        RestClient::Request.execute(method: :post, url: url, payload: request_payload, headers: req_headers, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      rescue Exception => e
        raise e.message
      end
    end

    def payload
      {
        "notification_name" => notification_name,
        "client_code": Rails.application.credentials.client_code,
        "client_name": Rails.application.credentials.account_name,
        "recipient" => {
          "delivery_address" => recipient, "bcc_recipient" => bcc_recipient
        },
        "custom_data" => custom_data
      }
    end

    def headers
      # url = "#{Rails.application.credentials.rule_engine_host}/users/sign_in"
      # payload = {
      #   user: {
      #     email: Rails.application.credentials.client_email, password: Rails.application.credentials.client_password
      #   }
      # }
      # response = RestClient::Request.execute(method: :post, url: url, payload: payload, verify_ssl: OpenSSL::SSL::VERIFY_NONE)
      headers = {}
      # headers["Authorization"] = response.headers[:authorization] if response.present?
      headers["Accept"] = "application/json"
      headers
    end

    def export_to_aws(file, file_name)
      amazon_s3 = Aws::S3::Resource.new(region: Rails.application.credentials.aws_s3_region, access_key_id: Rails.application.credentials.access_key_id, secret_access_key: Rails.application.credentials.secret_access_key)
      bucket = Rails.application.credentials.rule_engine_bucket
      obj = amazon_s3.bucket(bucket).object("uploads/inward_visibility_reports/#{file_name}")
      obj.put(body: file, acl: 'public-read', content_disposition: 'attachment', content_type: 'text/csv')
      obj.public_url
    end
  end
end
