class RepairSerializer < ActiveModel::Serializer
  attributes :id, :item_id, :article_id, :article_description, :grade, :benchmark_price, :repair_amount, :repair_quote_percentage, :formatted_expected_revised_grade, 
  :repair_type_location, :current_repair_status, :disposition_name, :vendor_code
  

  # :id, :item_id, :article_id, :article_description, :email_date,
  # :repair_location, :rgp_number, :repair_amount, :authorized_by, :repair_date,  :status, 
  # :status_id, :serial_number, :details, :pending_initiation_ageing, :pending_quotation_ageing, 
  # :pending_approval_ageing, :pending_repair_ageing, :pending_grade_ageing, :pending_disposition_ageing,
  # :grade_summary, :client_sku_master_id, :brand, :grade, :map,
  # :pending_initiation_attachments,
  # :pending_quotation_attachments,
  # :pending_approval_attachments,
  # :pending_repair_attachments,
  # :pending_repair_grade_attachments,
  # :pending_repair_rgp_number,
  # :pending_repair_location,
  # :serial_no,
  # :alert_level,
  # :ageing_dispatch,
  # :repair_quote_percentage, :repair_type_location, :current_repair_status, :benchmark_price, 
  # :formatted_expected_revised_grade, :vendor_name, :vendor_code, :disposition_name

  
  # def pending_repair_rgp_number
  #   object.pending_repair_rgp_number  || ''
  # end

  # def pending_repair_location
  #   object.pending_repair_location  || ''
  # end

  def formatted_expected_revised_grade
    object.expected_revised_grade&.humanize
  end

  def repair_type_location
    object.repair_type&.humanize
  end

  def disposition_name
    object.assigned_disposition
  end

  def item_id
    object.tag_number  || 'NA'
  end

  def article_id
    object.sku_code  || 'NA'
  end

  def current_repair_status
    object.repair_status&.humanize
  end

  def benchmark_price
    object.item_price
  end

  def alert_level
    object.details['criticality']
  end

  def serial_number 
    object.details['serial_number']  || 'NA'
  end

  def article_description
    object.item_description || 'NA'
  end 

  def map
    object.inventory.item_price || 'NA'
  end

  #Ageing
  def pending_initiation_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    initiation_date = orh.details["pending_repair_initiation_created_date"].present? ? (Date.today.to_date - orh.details["pending_repair_initiation_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return initiation_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''
  end

  def ageing_dispatch
    status_change_date = object.repair_histories.find_by_status_id(object.status_id).created_at rescue 0
    "#{(Date.today.to_date - status_change_date.to_date).to_i} d" rescue "0 d"
  end
  
  def pending_quotation_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    quotation_date = orh.details["pending_repair_quotation_created_date"].present? ? ( Date.today.to_date - orh.details["pending_repair_quotation_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return quotation_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''    
  end

  def pending_approval_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    approval_date = orh.details["pending_repair_approval_created_date"].present? ? ( Date.today.to_date - orh.details["pending_repair_approval_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return approval_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''    
  end 

  def pending_repair_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    repair_date = orh.details["pending_repair_created_date"].present? ? ( Date.today.to_date - orh.details["pending_repair_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return repair_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''    
  end

  def pending_grade_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    grade_date = orh.details["pending_repair_grade_created_date"].present? ? (Date.today.to_date - orh.details["pending_repair_grade_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return grade_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''    
  end

  def pending_disposition_ageing
    orh = object.repair_histories.find_by_status_id(object.status_id)
    return '' unless orh.present?
    disposition_date = orh.details["pending_repair_disposition_created_date"].present? ? (Date.today.to_date - orh.details["pending_repair_disposition_created_date"].to_date).to_i : 0
    inward_date = (Date.today.to_date - object.inventory.details["grn_received_time"].to_date).to_i rescue 0
    return disposition_date.to_s+'d ' + ' ' + "(" + inward_date.to_s + "d" + ")" rescue ''    
  end

  #Attachments
  def pending_initiation_attachments
    repair_attachments = object.repair_attachments.where(attachment_type: "Pending Repair Initiation") rescue []
     name_list(repair_attachments)
  end 


  def pending_quotation_attachments
    repair_attachments = object.repair_attachments.where(attachment_type: "Pending Repair Quotation") rescue []
     name_list(repair_attachments)
  end 

  def pending_approval_attachments
    repair_attachments = object.repair_attachments.where(attachment_type: "Pending Repair Approval") rescue []
     name_list(repair_attachments)
  end

  def pending_repair_attachments
    repair_attachments = object.repair_attachments.where(attachment_type: "Pending Repair") rescue []
     name_list(repair_attachments)
  end

  def pending_repair_grade_attachments
    repair_attachments = object.repair_attachments.where(attachment_type: "Pending Repair Grade") rescue []
     name_list(repair_attachments)
  end

  def name_list(repair_attachments)
    data = []
    repair_attachments.each do|ra|
      data << {name: ra.attachment_name, url: ra.attachment_file_url}
    end
    data  
  end

  def grade_summary
    object.inventory.inventory_grading_details.last.grade_summary rescue ''
  end 


  def serial_no
    if object.serial_number  && object.serial_number_2
      return object.serial_number , object.serial_number_2
    elsif   !object.serial_number_2  && object.serial_number
      return object.serial_number
    elsif   !object.serial_number  && object.serial_number
      return  object.serial_number_2
    end    
  end  
  
end