class Api::V1::Warehouse::WarehouseOrderItemSerializer < ActiveModel::Serializer

  attributes :id, :warehouse_order_item_id, :tag_number, :inventory_id, :lot_id, :lot_name, :outward_reason_ref_order, :destination_type, :destination, :pickup_request_status, :category, :sku_master_code, :sku_code, :item_description, :distribution_center_id, :distribution_center, :sub_location, :reject_reason, :orderable_type, :grade

  #& Column defined attributes
  def warehouse_order
    object.warehouse_order
  end
  
  def lot_name
    ((warehouse_order.orderable.lot_name.present? rescue false) ? warehouse_order.orderable.lot_name : (VendorMaster.find_by_vendor_code(warehouse_order.vendor_code).vendor_name) rescue "")
  end

  def lot_id
    warehouse_order.orderable_id
  end
  
  def orderable_type
    warehouse_order.orderable_type
  end

  def pickup_request_status
    object.dispatch_request_status.to_s.humanize
  end

  def outward_reason_ref_order
    object.orrd
  end

  def category
    inventory.details['category_l3']
  end
  
  def distribution_center_id
    inventory.distribution_center_id
  end
  
  def distribution_center
    inventory.distribution_center&.code
  end
  
  def sub_location
    inventory.sub_location&.code
  end
  
  def reject_reason
    object.reject_reason&.titleize
  end
  
  def warehouse_order_item_id
    object.id
  end
  
  def sku_code
    object.sku_master_code
  end
  
  def grade
    inventory.grade
  end

  def inventory
    object.inventory || object.forward_inventory
  end
end
