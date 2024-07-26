class OrderSerializer < ActiveModel::Serializer
  
  attributes :id, :order_number, :from_address, :to_address, :deleted_at, :created_at, :updated_at

  has_one :client
  has_one :user
  has_one :order_type
  
end
