class Api::V2::Warehouse::VendorReturnWarehouseOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :tag_number, :article_id, :brand, :vendor, :order_number, :status, :tab_status, :invoice_number, :item_description

  def article_id
    (object.inventory.sku_code rescue 'NA')
  end

  def brand
    object.details['brand']
  end

  def vendor
    object.inventory&.vendor_return&.details&.dig('bcl_supplier') rescue 'N/A'
  end

  def order_number
    object.warehouse_order&.reference_number
  end

  def status
    object.tab_status_to_status[object.tab_status.to_sym]  rescue ''
  end

  def invoice_number
    object.inventory.details&.dig('invoice_number') || 'N/A'
  end

  def item_description
    object.item_description
  end
end
