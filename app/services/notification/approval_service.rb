# frozen_string_literal: true

module Notification
  class ApprovalService < BaseService
    attr_accessor :approval_configuration, :approval_users

    def initialize(approval_configuration)
      @approval_configuration = approval_configuration
      @approval_users = approval_configuration.approval_users
    end

    def call
      payload = {
        client_approval_config_id: approval_configuration.id,
        approval_name:approval_configuration.approval_name,
        client_name: Rails.application.credentials.account_name,
        client_code: Rails.application.credentials.client_code,
        approval_type: approval_configuration.approval_config_type,
        approval_flow: approval_configuration.approval_flow,
        users_data: build_users_data,
        approval_count: approval_configuration.approval_count
      }
      trigger_api_sync(payload, 'approval_configurations')
    end

    def build_users_data
      hash = {}
      approval_users.each do |approval_user|
        hash[approval_user.heirarchy_level] ||= []
        hash[approval_user.heirarchy_level] = [approval_user.user.id, approval_user.user.email]
      end
      hash
    end
  end
end
