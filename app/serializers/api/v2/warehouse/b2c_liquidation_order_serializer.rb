class Api::V2::Warehouse::B2cLiquidationOrderSerializer < ActiveModel::Serializer
  attributes :publish_id, :article_id, :article_description, :grade, :platform, :quantity

  def publish_id
    object.ecom_liquidations.first&.id
  end

  def article_id
    object.liquidations&.first&.id
  end

  def article_description
    object.liquidations&.first&.item_description
  end

  def grade
    object.liquidations&.first&.grade
  end
end
