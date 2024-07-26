class Api::V1::ApprovalUserSerializer < ActiveModel::Serializer
  attributes :id, :heirarchy_level, :user_id
end
