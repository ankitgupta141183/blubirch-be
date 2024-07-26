class Api::V1::LookupValueSerializer < ActiveModel::Serializer
  
  attributes :id, :ancestry, :code, :original_code, :position

  has_one :lookup_key
  
end
