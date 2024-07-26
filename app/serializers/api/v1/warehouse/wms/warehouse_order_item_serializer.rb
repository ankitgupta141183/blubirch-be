class Api::V1::Warehouse::Wms::WarehouseOrderItemSerializer < ActiveModel::Serializer

  attributes :id, :warehouse_order_id, :article_id, :article_description, :grade, :category, :inventory_id, :client_category_id, :client_category_name, :sku_master_code, :item_description, :tag_number, :serial_number, :aisle_location, :quantity, :toat_number, :source, :details, :status_id, :packaging_box_number, :packaging_box_id, :status, :deleted_at, :created_at, :updated_at, :order_number, :repair_vendor, :repair_quote, :returnable_dc_number, :repair_vendor_code, :restock_location, :price, :chalan, :tab_status

  def article_id
    (object.inventory.sku_code rescue 'NA')
  end

  def article_description
    (object.inventory.item_description rescue 'NA')
  end

  def source
    object.details['source_code'] rescue ''
  end

  def packaging_box_id
    if object.packaging_box_number.present?
      return instance_options[:box_number_hash].present? && instance_options[:box_number_hash][object.packaging_box_number].present? ? instance_options[:box_number_hash][object.packaging_box_number] : ''
    else
      ""
    end
  end

  def order_number
    object.warehouse_order.orderable.order_number
  end

  def status
    object.tab_status_to_status[object.tab_status.to_sym]  rescue ''
  end

  def price
    (object.inventory.item_price rescue 0)
  end

  def grade
    (object.inventory.grade rescue 'NA')
  end

  def category
    object.details['category_l1']
  end

  #^ -------------------- REPAIR PART --------------------------
  def repair_vendor
    VendorMaster.find_by_vendor_code(object.warehouse_order.orderable.repairs.last.vendor_code).vendor_name rescue ''
  end

  def repair_vendor_code
    object.warehouse_order.orderable.repairs.last.vendor_code rescue ''
  end

  def repair_quote
    object.warehouse_order.orderable.repairs.last.repair_amount rescue 0
  end

  def returnable_dc_number
    (object.ord rescue '')
  end

  #^ -------------------- RESTOCK PART --------------------------------

  def restock_location
    "L-#{VendorMaster.find_by_vendor_code(object.warehouse_order.orderable.vendor_code).id}" rescue ''
  end

  def chalan
    'NA'
  end

end