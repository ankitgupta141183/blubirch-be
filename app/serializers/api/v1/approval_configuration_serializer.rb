class Api::V1::ApprovalConfigurationSerializer < ActiveModel::Serializer
  attributes :id, :approval_name, :approval_config_type, :approval_flow, :approval_count

  has_many :approval_users
end
