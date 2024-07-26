class ClientCategorySerializer < ActiveModel::Serializer

  belongs_to :client

attributes :id, :name, :ancestry, :code, :attrs,  :created_at, :updated_at, :deleted_at,  :parent_name , :client_id

  def parent_name
    object.parent.name rescue nil
  end
  
end
