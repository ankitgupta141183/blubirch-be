class Api::V1::ClientCategorySerializer < ActiveModel::Serializer

	belongs_to :client
	attributes :id, :name, :ancestry, :code, :attrs,  :created_at, :updated_at, :deleted_at , :client_id, :root_category, :leaf_category, :child_category

  def root_category
    root_category = ClientCategory.find(object.id).root rescue nil
  end

  def leaf_category
  	leaf_category = ClientCategory.find(object.id).is_childless? 
  end

  def child_category
  	child_category = ClientCategory.find(object.id).children
  end

end
