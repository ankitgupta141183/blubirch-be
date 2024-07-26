class Api::V1::Warehouse::RepairWarehouseOrderItemSerializer < ActiveModel::Serializer
  attributes :id, :article_id, :article_description, :item_description, :tag_number, :status, :order_number, :repair_vendor, :repair_quote, :returnable_dc_number, :repair_vendor_code, :amount, :tab_status, :ord

  def article_id
    (object.inventory.sku_code rescue 'NA')
  end

  def article_description
    (object.inventory.item_description rescue 'NA')
  end

  def order_number
    object.warehouse_order.reference_number
  end

  def price
    (object.inventory.item_price rescue 0)
  end

  def repair_vendor
    object.warehouse_order.vendor_name
  end

  def status
    object.tab_status_to_status[object.tab_status.to_sym] rescue ''
  end

  def repair_vendor_code
    object.warehouse_order.vendor_code rescue ''
  end

  def repair_quote
    #object.warehouse_order.orderable.repairs.last.repair_amount rescue 0
    object.amount.to_f
  end

  def returnable_dc_number
    (object.ord rescue '')
  end
end
