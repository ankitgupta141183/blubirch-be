class Api::V1::Warehouse::ReplacementSerializer < ActiveModel::Serializer
  #attributes :id, :inventory_id, :sku_code, :item_description, :vendor, :tag_number, :ageing, :alert_level, :status, :disposition_set, :ageing_dispatch, :attached_file_url, :call_log_id, :grade, :sr_number, :replacement_location, :rgp_number, :grade_summary, :pending_inspection_attachments, :pending_resolution_attachments, :pending_replacement_attachments, :pending_disposition_attachments, :pending_call_log_attachments, :call_log_remarks, :replacement_remark, :action_remark, :item_replaced, :call_log_date, :replacement_date, :brand, :approval_code, :confirmed_status
  attributes :id, :sku_code, :return_method, :item_description, :vendor, :tag_number, :status, :grade, :item_replaced, :replacement_date, :brand, :approval_code, :confirmed_status, :return_date, :item_price, :has_replacement_order, :order_number, :replacement_dc_number

  def vendor
    object.vendor_name
  end

  def order_number
    object.replacement_order.order_number rescue 'NA'
  end

  def replacement_dc_number
    object.replacement_order.warehouse_orders.pluck(:outward_invoice_number).join(',') rescue 'NA'
  end

  def brand
    object.details['brand']
  end

  def has_replacement_order
    object.replacement_order_id.present?
  end

  def ageing
    "#{(Date.today.to_date - (object.inventory.details["grn_received_time"].to_date)).to_i} d" rescue "0 d"
  end

  def confirmed_status
    object.is_confirmed? ? 'Confirmed' : 'Not Confirmed'
  end


  def alert_level
    object.details['criticality']
  end

  def ageing_dispatch
    status_change_date = object.replacement_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end

  def attached_file_url
    object.rtv_attachments.where(attachment_file_type: 'Approve/Reject').last.attachment_file_url rescue ''
  end

  def disposition_set
    return object.details['disposition_set']
  end

  def sr_number
    str = ''
    str = object.serial_number if object.serial_number.present?
    str = "#{object.serial_number}, #{object.serial_number_2}" if (object.serial_number_2.present? && object.serial_number.present?)
    str = object.serial_number_2 if ( object.serial_number_2.present? && str.blank?)
    return str
  end

  def grade_summary
    object.inventory.inventory_grading_details.last.grade_summary rescue ''
  end

  def pending_call_log_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_call_log)
    replacement_attachments = object.replacement_attachments.where(attachment_type_id: file_type.id) rescue []
    name_list(replacement_attachments)
  end 


  def pending_inspection_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_inspection)
    replacement_attachments = object.replacement_attachments.where(attachment_type_id: file_type.id) rescue []
    name_list(replacement_attachments)
  end 

  def pending_resolution_attachments
    approved_file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_approved)
    rejected_file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_reject)
    replacement_attachments = object.replacement_attachments.where(attachment_type_id: [approved_file_type.id, rejected_file_type.id]) rescue []
     name_list(replacement_attachments)
  end

  def pending_replacement_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_detail)
    replacement_attachments = object.replacement_attachments.where(attachment_type_id: file_type.id) rescue []
    name_list(replacement_attachments)
  end

  def pending_disposition_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.replacement_file_type_replacement_disposition)
    replacement_attachments = object.replacement_attachments.where(attachment_type_id: file_type.id) rescue []
    name_list(replacement_attachments)
  end

  def name_list(replacement_attachments)
    data = []
    replacement_attachments.each do|ra|
      h = {}
      h['name'] = ra.attachment_name
      h['url'] = ra.attachment_file_url
      data << h
    end
    data  
  end

  def replacement_location
    (object.replacement_location == "External Location") ? object.rgp_number : object.replacement_location rescue nil
  end

  def item_replaced
    object.details['old_replacement_id'].present?
  end

end
