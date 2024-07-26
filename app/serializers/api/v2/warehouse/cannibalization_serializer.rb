class Api::V2::Warehouse::CannibalizationSerializer < ActiveModel::Serializer
  
  attributes :id, :tag_id, :article_id, :item_description, :ageing, :quantity, :uom, :condition, :article_type, :tote_id, :ready_to_be_cannibalized
  
  def tag_id
    object.tag_number || 'NA'
  end

  def article_id
    object.sku_code || "NA"
  end

  def quantity
    object.quantity_with_sub_cannibalize_items
  end
end
