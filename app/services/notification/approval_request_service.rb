# frozen_string_literal: true

module Notification
  class ApprovalRequestService < BaseService
    attr_accessor :approval_request

    def initialize(approval_request)
      @approval_request = approval_request
    end

    def call
      payload = {
        client_name: Rails.application.credentials.account_name,
        client_code: Rails.application.credentials.client_code,
        client_request_id: approval_request.id,
        approval_configuration_id: approval_request.approval_configuration_id,
        is_rule_based: true,
        rule_field: approval_request.rule_field,
        type: approval_request.approval_rule_type,
        value: approval_request.value.to_i,
        details: approval_request.details
      }
      trigger_api_sync(payload, 'approval_requests')
    end
  end
end