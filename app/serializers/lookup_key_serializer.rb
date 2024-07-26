class LookupKeySerializer < ActiveModel::Serializer
  
  attributes :id, :name, :code, :created_at, :updated_at, :deleted_at
  
end
