class CategorySerializer < ActiveModel::Serializer

  attributes :id, :name, :parent, :code, :attrs,  :created_at, :updated_at, :deleted_at

end


