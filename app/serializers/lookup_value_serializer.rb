class LookupValueSerializer < ActiveModel::Serializer
  
  attributes :id, :parent, :code, :original_code, :position, :created_at, :updated_at, :deleted_at

  has_one :lookup_key
  
end
