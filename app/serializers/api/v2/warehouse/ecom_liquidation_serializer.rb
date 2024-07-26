class Api::V2::Warehouse::EcomLiquidationSerializer < ActiveModel::Serializer
  attributes :id, :article_id, :article_description, :grade, :platform, :quantity, :publish_id, :status, :publish_status

  def article_id
    object.inventory_sku
  end

  def article_description
    object.inventory_description
  end

  def publish_id
    object.external_product_id
  end

end
