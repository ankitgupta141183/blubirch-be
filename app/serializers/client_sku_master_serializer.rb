class ClientSkuMasterSerializer < ActiveModel::Serializer
	
  attributes :id,  :client_category_id, :code, :description, :item_type, :created_at, :updated_at, :deleted_at, :client_category, :attrs_fields, :sku_description, :brand, :own_label
	
  belongs_to :client_category

  def attrs_fields
  	object.client_category.attrs
  end

end
