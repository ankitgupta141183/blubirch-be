class Api::V1::Warehouse::RestockSerializer < ActiveModel::Serializer
  attributes :id, :tag_number, :article_id, :article_description, :asp, :category, :grade, :is_putaway_inwarded

  def article_id
    object.sku_code  || 'NA'
  end

  def article_description
    object.item_description || 'NA'
  end 

  def asp
    object.details['asp']
  end

  def is_putaway_inwarded
    object.inventory.putaway_inwarded?
  end
end
