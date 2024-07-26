class Api::V1::Warehouse::Wms::WarehouseOrderSerializer < ActiveModel::Serializer

  attributes :id, :order_number, :vendor_code, :vendor_name, :partially_dispatched, :status, :distribution_center_id, :client_id, :status_id, :warehouse_gatepass_id, :warehouse_consignment_id, :reference_number, :total_quantity, :gatepass_number, :outward_invoice_number, :items_by_category, :warehouse_consignment_file_types, :details, :deleted_at, :created_at, :updated_at, :lot_name, :lot_id, :lot_type, :warehouse_order_items, :adjustment_reason, :adjustment_amount, :winner_amount
  #has_many :warehouse_order_items

  def order_number
    object.orderable.order_number rescue ''
  end

  def vendor_code
      #  no need take from ordrable 
      return object.vendor_code
  end

  def partially_dispatched
    status_ids = [] 
    status_ids << instance_options[:statuses][:partial_dispatch_status] << instance_options[:statuses][:in_dispatch_status]
    if status_ids.include?(object.status_id)
      if object.warehouse_order_items.where(status: "Pending Dispatch").present? || object.warehouse_order_items.where(status: "In Dispatch").present?
        return true
      else
        return false
      end
    else
      return true
    end
  end

  def vendor_name
    vendor_master = VendorMaster.find_by(vendor_code: object.vendor_code)
    if vendor_master.present?
      return vendor_master.vendor_name
    else
      object.vendor_code
    end
  end

  def items_by_category
    items = []
    res = object.warehouse_order_items.group(:sku_master_code, :item_description).size.to_a rescue ''
    res.each do |r|
      items << r.flatten
    end
    return items
  end

  def status
    LookupValue.find_by(id: object.status_id).original_code rescue ''
  end

  def warehouse_consignment_file_types
    instance_options[:warehouse_consignment_file_types]
  end

  def warehouse_order_items
    box_numbers = PackagingBox.where(box_number: object.warehouse_order_items.pluck(:packaging_box_number)).pluck(:box_number, :id).to_h
    ActiveModel::Serializer::CollectionSerializer.new(object.warehouse_order_items, serializer: Api::V1::Warehouse::Wms::WarehouseOrderItemSerializer, box_number_hash: box_numbers)
  end

  def lot_name
    ((object.orderable.lot_name.present? rescue false) ? object.orderable.lot_name : (VendorMaster.find_by_vendor_code(object.vendor_code).vendor_name) rescue "")
  end

  def lot_id
    object.orderable.id rescue 0
  end

  def lot_type
    if object.orderable_type == 'LiquidationOrder'
      object.orderable.lot_type rescue ""
    elsif object.orderable_type == 'RedeployOrder'
      'Redeploy'
    elsif object.orderable_type == 'VendorReturnOrder'
      'RTV'
    elsif object.orderable_type == 'TransferOrder'
      'Restock'  
    elsif object.orderable_type == 'RepairOrder'
      'Repair'  
    else
      ""
    end
  end

  def adjustment_reason
    (object.orderable_type == 'LiquidationOrder' ? object.orderable.details['adjustment_reason'] : '' rescue '')
  end

  def adjustment_amount
    (object.orderable_type == 'LiquidationOrder' ? object.orderable.details['adjustment_amount'] : 0 rescue 0)
  end

  def winner_amount
    (object.orderable_type == 'LiquidationOrder' ? object.orderable.winner_amount : 0 rescue 0)
  end

end