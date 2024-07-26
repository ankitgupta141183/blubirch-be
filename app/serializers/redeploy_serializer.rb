class RedeploySerializer < ActiveModel::Serializer
  attributes :id, :item_id, :article_id, :article_description, :serial_number, :grade_summary,
  :source_code, :destination_code, :status_id, :status, 
  :pending_destination_remarks, :pending_destination_ageing, :pending_destination_attachments,
  :pending_dispatch_ageing, :alert_level, :ageing_dispatch

  def item_id
    object.tag_number  || 'NA'
  end

  def article_id
    object.sku_code  || 'NA'
  end

  def alert_level
    object.details['criticality']
  end

  def article_description
    object.item_description || 'NA'
  end 

  def serial_number
    str = ''
    str = object.serial_number if object.serial_number.present?
    str = "#{object.serial_number}, #{object.serial_number_2}" if (object.serial_number_2.present? && object.serial_number.present?)
    str = object.serial_number_2 if ( object.serial_number_2.present? && str.blank?)
    return str
  end

  def pending_destination_attachments
    repair_attachments = object.redeploy_attachments.where(attachment_file_type: "Pending Redeploy Destination") rescue []
    name_list(repair_attachments) 
  end

  def name_list(repair_attachments)
    data = []
    repair_attachments.each do|ra|
      data << ra.attachment_name
    end
    data  
  end

  def grade_summary
    object.inventory.inventory_grading_details.last.grade_summary rescue ''
  end

  def pending_destination_ageing 
    orh = object.redeploy_histories.where(status_id: LookupValue.find_by(code: Rails.application.credentials.redeploy_status_pending_redeploy_destination).try(:id)).first
    return '' unless orh.present?
    destination_date = orh.details["pending_redeploy_destination_created_date"].present? ? (Date.today.to_date - orh.details["pending_redeploy_destination_created_date"].to_date).to_i : 0 rescue nil
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i || 0 rescue nil
    return destination_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''
  end

  def pending_dispatch_ageing 
    status_change_date = object.redeploy_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end

  def ageing_dispatch
    status_change_date = object.redeploy_histories.find_by_status_id(object.status_id).created_at rescue nil
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end
end