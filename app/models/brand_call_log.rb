class BrandCallLog < ApplicationRecord
  belongs_to :inventory
  belongs_to :distribution_center
  has_many :rtv_attachments, as: :attachable
  has_many :brand_call_log_histories
  has_many :approval_requests, as: :approvable
  
  mount_uploader :inspection_report, ConsignmentFileUploader
  
  include JsonUpdateable
  
  before_create :update_required_documents
  validate :validate_ticket_number
  
  enum status: { pending_information: 1, pending_bcl_ticket: 2, pending_inspection: 3, pending_decision: 4, pending_disposition: 5, closed: 6 }, _prefix: true
  
  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      user = User.find_by_id(user_id) || inventory.user
      
      recent_call_log_id = self.where(tag_number: inventory.tag_number).last&.call_log_id

      brand_call_log = BrandCallLog.new(inventory_id: inventory.id, tag_number: inventory.tag_number, distribution_center_id: inventory.distribution_center_id, grade: inventory.grade,
        brand: inventory.details["brand"], details: inventory.details, call_log_id: recent_call_log_id, sku_code: inventory.sku_code, item_description: inventory.item_description,
        item_price: inventory.item_price, sr_number: inventory.sr_number, serial_number: inventory.serial_number, serial_number2: inventory.serial_number_2, toat_number: inventory.toat_number,
        client_tag_number: inventory.client_tag_number, supplier: inventory.details["supplier"], benchmark_price: inventory.details["purchase_price"].to_f, status: "pending_information"
      )
      brand_call_log.save!
      bucket_status = LookupValue.find_by(code: "brand_call_log_status_pending_information")
      brand_call_log.update_history(bucket_status, user)
    end
  end
  
  def update_inventory_status(code, user = nil)
    inventory = self.inventory
    bucket_status = LookupValue.find_by(code: code)
    raise CustomErrors.new "Invalid code." if bucket_status.blank?
    
    inventory.update_inventory_status!(bucket_status)
    update_history(bucket_status, user)
  end
  
  def update_history(bucket_status, user)
    bcl_history = self.brand_call_log_histories.new(status_id: bucket_status.id)
    bcl_history.details = {"status_changed_by_user_id" => user&.id, "status_changed_by_user_name" => user&.full_name}
    bcl_history.save
  end
  
  def update_required_documents
    data = [{field: "Purchase Invoice No", data_type: "info", is_mandatory: true}, {field: "DOA Certificate", data_type: "doc", is_mandatory: true}]
    self.required_documents = data
  end
  
  def get_required_documents
    data = []
    self.required_documents.each do |document|
      field_data = {field: document["field"].parameterize.underscore, label: document["field"], data_type: document["data_type"], is_mandatory: document["is_mandatory"]}
      if document["data_type"] == "info"
        field_data["value"] = self.info_data[document["field"]] rescue ""
      else
        attachment = self.rtv_attachments.find_by(attachment_file_type: field_data[:label])
        field_data[:value] = attachment.present? ? { name: attachment&.attachment_file&.file&.filename, url: attachment&.attachment_file_url } : nil
      end
      data << field_data
    end
    data
  end
  
  # data = {field: "incident_images", label: "Incident Images", data_type: "image", file: file, value: ""}
  def update_document(data = {})
    raise CustomErrors.new "Insufficient data." if (data[:field].blank? || data[:label].blank? || data[:data_type].blank?)
    
    if data[:data_type] == "info"
      raise CustomErrors.new "Info can not be blank for #{data[:label]}." if data[:value].blank?
      
      self.info_data ||= {}
      self.info_data[data[:label]] = data[:value]
      self.update_field(data[:label])
      self.save!
      message = "Data updated successfully."
    else
      raise CustomErrors.new "Please upload document for #{data[:label]}." if data[:file].blank?
      
      validate_file_format(data[:file], data[:data_type])
      
      attachment = self.rtv_attachments.find_or_initialize_by(attachment_file_type: data[:label])
      attachment.attachment_file = data[:file]
      attachment.save!
      self.update_field(data[:label])
      
      message = "Document uploaded successfully."
    end
    
    return message
  end
  
  IMG_FORMATS = %w(.jpg .jpeg .gif .png)
  VIDEO_FORMATS = %w(.mp4 .avi .mov)
  FILE_FORMATS = %w(.jpg .jpeg .png .pdf .doc .docx)
  def validate_file_format(file, data_type)
    ext = File.extname(file.original_filename)
    if data_type == "image"
      formats = IMG_FORMATS
    elsif data_type == "video"
      formats = VIDEO_FORMATS
    elsif data_type == "doc"
      formats = FILE_FORMATS
    end
    raise CustomErrors.new "Invalid file format for #{data_type}" unless formats.include? ext
  end
  
  def update_field field
    document = self.required_documents.select{|f| f["field"] == field }[0]
    raise CustomErrors.new "Invalid Document Name" if document.blank?
    document["is_updated"] = true
    self.save!
  end
  
  def check_for_pending_bcl_ticket?
    pending_docs = self.required_documents.select{|d| (d["is_mandatory"] == true and d["is_updated"] != true) }
    return false if pending_docs.present?
    return true
  end
  
  def pending_documents
    return [] if self.required_documents.blank?
    self.required_documents.select{|d| d["is_updated"] != true }
  end
  
  def set_disposition(disposition, current_user = nil)
    raise CustomErrors.new "Disposition can't be blank!" if disposition.blank?

    current_status =  self.status

    self.details['disposition_set'] = true
    self.is_active = false
    self.approver_id = current_user&.id
    self.status = :closed
    self.save!
    
    inventory = self.inventory
    #self.update_inventory_status(disposition, current_user&.id)
    inventory.disposition = disposition
    inventory.details ||= {}
    inventory.details['bcl_supplier'] = supplier if supplier.present?
    inventory.details['bcl_approval_code'] = approval_ref_number if approval_ref_number.present?
    inventory.save!
    
    case disposition
    when "Repair"
      if current_status == "pending_disposition"
        Repair.create_record(inventory, current_user&.id)
      else
        Repair.set_manual_disposition(inventory, current_user&.id, self.details["repair_type"])
      end
    else
      DispositionRule.create_bucket_record(disposition, inventory, 'BrandCallLog', current_user&.id)
    end
  end
  
  def validate_ticket_number
    return true if (ticket_number.blank? || ticket_number.index( /[^[:alnum:]]/ ).blank?)
    raise CustomErrors.new "Ticket number cannot contain special characters"
  end
  
  def get_recovery_percent
    return 0.0 if (self.net_recovery.to_f == 0 || self.benchmark_price.to_f == 0)
    return (self.net_recovery / self.benchmark_price.to_f) * 100
  end
  
  def get_vendor_code
    VendorMaster.find_by_vendor_name(self.supplier)&.vendor_code
  end

  def self.bind_status_look_values
    { 
      'Pending Information' => :pending_information,
      'Pending BCL Ticket' => :pending_bcl_ticket,
      'Pending Inspection' => :pending_inspection,
      'Pending Decision' => :pending_decision,
      'Pending Disposition' => :pending_disposition,
      'Pending Closed' => :closed
    }
  end
end
