class Api::V1::Warehouse::OldInsuranceSerializer < ActiveModel::Serializer
  attributes :id, :inventory_id, :sku_code, :item_description, :vendor, :tag_number, :ageing, :alert_level, :status, :disposition_set, :ageing_dispatch, :attached_file_url, :call_log_id, :grade, :insurance_order_id, :claim_amount, :approved_amount, :sr_number, :aisle_location, :warehouse_location, :claim_submission_remarks, :claim_inspection_remarks, :action_remarks, :pending_submission_attachments, :pending_inspection_attachments, :pending_resolution_attachments, :claim_submission_date, :claim_inspection_date

  def vendor
    object.details['brand']
  end

  def approved_amount
    object.approved_amount.present? ? object.approved_amount : 0
  end

  def ageing
    "#{(Date.today.to_date - (object.inventory.details["grn_received_time"].to_date)).to_i} d" rescue "0 d"
  end

  def sr_number
    str = ''
    str = object.serial_number if object.serial_number.present?
    str = "#{object.serial_number}, #{object.serial_number_2}" if (object.serial_number_2.present? && object.serial_number.present?)
    str = object.serial_number_2 if ( object.serial_number_2.present? && str.blank?)
    return str
  end

  def alert_level
    object.details['criticality']
  end

  def ageing_dispatch
    status_change_date = object.insurance_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end

  def aisle_location
    object.distribution_center.name rescue nil
  end

  def attached_file_url
    file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_disposition)
    object.insurance_attachments.where(attachment_file_type: file_type.original_code).last.attachment_file_url rescue ''
  end

  def disposition_set
    return object.details['disposition_set']
  end

  def warehouse_location
    object.distribution_center.name rescue nil
  end


  def pending_submission_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_submission)
    insurance_attachments = object.insurance_attachments.where(attachment_file_type: file_type.original_code) rescue []
    name_list(insurance_attachments)
  end 


  def pending_inspection_attachments
    file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_inspection)
    insurance_attachments = object.insurance_attachments.where(attachment_file_type: file_type.original_code) rescue []
    name_list(insurance_attachments)
  end 

  def pending_resolution_attachments
    approved_file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_resolution)
    rejected_file_type = LookupValue.find_by_code(Rails.application.credentials.insurance_file_type_insurance_disposition)
    insurance_attachments = object.insurance_attachments.where(attachment_file_type: [approved_file_type.original_code, rejected_file_type.original_code]) rescue []
     name_list(insurance_attachments)
  end

  def name_list(insurance_attachments)
    data = []
    insurance_attachments.each do|ra|
      h = {}
      h['name'] = ra.attachment_name
      h['url'] = ra.attachment_file_url
      data << h
    end
    data
  end

end
