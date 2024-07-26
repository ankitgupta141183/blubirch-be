class Api::V1::Warehouse::VendorReturnSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :sku_code, :item_description, :item_price, :return_reason, :vendor, :tag_number, :ageing, :alert_level, :escalated_at, :reminded_at, :status, :dispatch_date, :dispatch_mode, :settlement_amount, :settlement_date, :disposition_set, :ageing_dispatch, :attached_file_url, :call_log_id, :grade, :vendor_return_order_id, :serial_number, :brand_inspection_date, :settlement_date, :claim_email_date, :gate_pass, :lot_name, :lot_id

  def vendor
    object.details['brand']
  end

  def return_reason
    object.inventory.return_reason
  end

  def ageing
    "#{(Date.today.to_date - (object.inventory.details["grn_received_time"].to_date)).to_i} d" rescue "0 d"
  end


  def alert_level
    object.details['criticality']
  end

  def attached_file_url
    object.rtv_attachments.where(attachment_file_type: 'Approve/Reject').last.attachment_file_url rescue ''
  end

  def escalated_at
    object.details['escalated_at'].to_date.strftime("%d/%m/%Y") rescue ''
  end

  def reminded_at
    object.details['reminded_at'].to_date.strftime("%d/%m/%Y") rescue ''
  end

  def dispatch_mode
    "Self Dispatch"
  end

  def ageing_dispatch
    status_change_date = object.vendor_return_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end

  def dispatch_date
    object.vendor_return_order.warehouse_orders.last.details['dispatch_complete_date'].to_date.strftime("%d/%m/%Y") rescue ''
  end

  def gate_pass
    object.vendor_return_order.warehouse_orders.last.gatepass_number rescue ''
  end

  def disposition_set
    return object.details['disposition_set']
  end

  def serial_number
    str = ''
    str = object.serial_number if object.serial_number.present?
    str = "#{object.serial_number}, #{object.serial_number2}" if (object.serial_number2.present? && object.serial_number.present?)
    str = object.serial_number2 if ( object.serial_number2.present? && str.blank?)
    return str
  end

  def lot_name
    object.vendor_return_order.present? ? object.vendor_return_order.lot_name : ""
  end

  def lot_id
    object.vendor_return_order.id rescue ""
  end

end
