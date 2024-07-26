class Api::V2::Warehouse::MarkdownSerializer < ActiveModel::Serializer
  
  attributes :id, :tag_id, :article_id, :article_description, :price, :category, :grade
  def tag_id
    object.tag_number || 'NA'
  end

  def article_id
    object.sku_code || "NA"
  end 

  def article_description
    object.item_description || 'NA'
  end

  def price
    object.asp.round(2) rescue 'NA'
  end

  def category
    object.inventory.client_category.name rescue nil
  end

end