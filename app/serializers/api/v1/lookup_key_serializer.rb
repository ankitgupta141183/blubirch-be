class Api::V1::LookupKeySerializer < ActiveModel::Serializer
  
  attributes :id, :name, :code

  has_many :lookup_values
  
end
