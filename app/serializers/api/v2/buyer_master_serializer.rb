class Api::V2::BuyerMasterSerializer < ActiveModel::Serializer
  attributes :id, :username, :email, :first_name, :last_name, :full_name
end
