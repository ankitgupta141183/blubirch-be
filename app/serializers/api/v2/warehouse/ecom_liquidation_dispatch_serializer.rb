class Api::V2::Warehouse::EcomLiquidationDispatchSerializer < ActiveModel::Serializer
  attributes :id, :article_id, :article_description, :platform, :publish_id, :dispatch_status, :buyer_name, :order_number, :purchase_amount, :invoice_amount, :invoice_number

  def article_id
    object.inventory_sku
  end

  def article_description
    object.inventory_description
  end

  def publish_id
    object.external_product_id
  end

  def dispatch_status
    (object.warehouse_order.warehouse_order_items.first.status rescue '')
  end

  def buyer_name
    (object.ecom_purchase_histories.last.username rescue '')
  end

  def purchase_amount
    object.amount
  end

  def invoice_number
    (object.warehouse_order.warehouse_order_items.first.ord rescue '')
  end

  def invoice_amount
    (object.ecom_purchase_histories.last.amount rescue '')
  end
end
