class ClientSerializer < ActiveModel::Serializer
  
  attributes :id, :name, :domain_name, :details, :created_at, :updated_at, :deleted_at
  
end
