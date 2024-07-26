class Api::V2::Warehouse::RentalSerializer < ActiveModel::Serializer
  
  attributes :id, :tag_id, :article_id, :article_description, :distribution_center
  
  def tag_id
    object.tag_number || 'NA'
  end

  def article_id
    object.article_sku || "NA"
  end

  def distribution_center
    object.distribution_center.code
  end
end