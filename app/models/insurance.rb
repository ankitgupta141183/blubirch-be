class Insurance < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory
  belongs_to :distribution_center
  belongs_to :insurance_order, optional: true
  belongs_to :insurer, optional: true
  belongs_to :approver, class_name: "User", foreign_key: :approver_id, optional: true
  belongs_to :assigner, class_name: "User", foreign_key: :assigned_id, optional: true

  has_many :insurance_histories
  has_many :insurance_attachments, as: :attachable
  has_many :approval_requests, as: :approvable
  # before_save :default_alert_level
  before_create :update_insurer
  
  mount_uploader :inspection_report, ConsignmentFileUploader
  mount_uploaders :incident_images, ConsignmentFileUploader
  mount_uploaders :incident_videos, ConsignmentFileUploader
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active

  enum insurance_status: { pending_information: 1, pending_claim_ticket: 2, pending_inspection: 3, pending_decision: 4, pending_disposition: 5, closed: 6 }, _prefix: true
  enum claim_decision: { approved: 1, partially_approved: 2, rejected: 3 }, _prefix: true

  validate :validate_approved_amount

  validate :validate_claim_ticket_number

  def update_insurer
    default_insurer = Insurer.first
    self.required_documents = default_insurer.required_documents
  end
  
  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      user = User.find_by_id(user_id)
      status = LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_submission)
      insurance_call_log_id = self.where(tag_number: inventory.tag_number).try(:last).try(:call_log_id)
      record = self.new
      record.inventory_id = inventory.id
      record.tag_number = inventory.tag_number
      record.distribution_center = inventory.distribution_center
      record.grade = inventory.grade
      record.sku_code = inventory.sku_code
      record.item_description = inventory.item_description
      record.sr_number = inventory.sr_number
      record.call_log_id = insurance_call_log_id
      record.details = inventory.details
      # record.details["criticality"] = "Low"
      record.status_id = status.id
      record.status = status.original_code
      record.details["serial_number"] = inventory.serial_number
      record.serial_number = inventory.serial_number
      record.serial_number_2 = inventory.serial_number_2
      record.aisle_location = inventory.aisle_location
      record.client_tag_number = inventory.client_tag_number
      record.toat_number = inventory.toat_number
      record.insurance_status = :pending_information
      record.responsible_vendor = inventory.details["supplier"]
      record.benchmark_price = inventory.details["purchase_price"].to_f

      if record.save
        bucket_status = LookupValue.find_by(code: "insurance_status_pending_information")
        record.update_history(bucket_status, user)
      end
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
    history = self.insurance_histories.new(status_id: bucket_status.id)
    history.details = {"status_changed_by_user_id" => user&.id, "status_changed_by_user_name" => user&.full_name}
    history.save
  end

  def call_log_or_claim_date
    self.claim_submission_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def visit_date
    self.claim_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def resolution_date_time
    self.resolution_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def check_active
    if self.inventory.present?
      return true if self.inventory.insurances.where.not(id: self.id).blank?
      return self.inventory.insurances.where.not(id: self.id).where(is_active: true).blank?
    end
  end
  
  def get_required_documents
    data = [{field: "incident_images", label: "Incident Images", data_type: "image", is_mandatory: true, value: get_incident_images}, {field: "incident_videos", label: "Incident Videos", data_type: "video", is_mandatory: true, value: get_incident_videos}]
    return data if self.required_documents.blank?
    self.required_documents.each do |document|
      field_data = {field: document["field"].parameterize.underscore, label: document["field"], data_type: document["data_type"], is_mandatory: document["is_mandatory"]}
      if document["data_type"] == "info"
        field_data["value"] = self.info_data[document["field"]] rescue ""
      else
        attachment = self.insurance_attachments.find_by(attachment_file_type: document["field"])
        field_data["value"] = attachment.present? ? { name: attachment&.attachment_file&.file&.filename, url: attachment&.attachment_file_url } : nil
      end
      data << field_data
    end
    data
  end
  
  def get_incident_images
    self.incident_images.map{ |i| { "name": i.file.filename, "url": i.url } }
  end
  
  def get_incident_videos
    self.incident_videos.map{ |i| { "name": i.file.filename, "url": i.url } }
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

      if (data[:field] == "incident_images" || data[:field] == "incident_videos")
        self.send("#{data[:field]}=", Array(data[:file]))                                            # self.incident_images += new_images - to append the images
        self.save!
      else
        attachment = self.insurance_attachments.find_or_initialize_by(attachment_file_type: data[:label])
        attachment.attachment_file = data[:file]
        attachment.save!
        self.update_field(data[:label])
      end
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
  
  def check_for_pending_claim_ticket?
    return false if (self.incident_images.blank? || self.incident_videos.blank?)
    pending_documents = self.required_documents.select{|d| (d["is_mandatory"] == true and d["is_updated"] != true) }
    return false if pending_documents.present?
    return true
  end
  
  def pending_documents
    return [] if self.required_documents.blank?
    self.required_documents.select{|d| d["is_updated"] != true } # .map{|d| d["field"] }
  end
  
  def self.common_hashes(arr)
    counts = {}
    arr.each do |subarr|
      subarr.each do |h|
        counts[h] ||= 0
        counts[h] += 1
      end
    end
    common = []
    counts.each do |h, count|
      common << h if count == arr.length
    end
    common
  end
  
  def set_disposition(disposition, current_user = nil)
    raise CustomErrors.new "Disposition can't be blank!" if disposition.blank?
    
    inventory = self.inventory
    self.details['disposition_set'] = true
    self.is_active = false
    self.resolution_date = Time.now
    self.approver_id = current_user&.id
    self.insurance_status = "closed"
    self.save!

    #self.update_inventory_status(disposition, current_user&.id)
    inventory.disposition = disposition
    inventory.save!

    DispositionRule.create_bucket_record(disposition, inventory, 'Insurance', current_user&.id)
  end

  def validate_approved_amount
    return true if self.claim_decision.blank?
    case self.claim_decision
    when "approved"
      raise CustomErrors.new "Approved amount should be same as claim amount" if self.claim_amount.to_f.round(2) != self.approved_amount.to_f.round(2)
    when "rejected"
      raise CustomErrors.new "Approved amount should be 0" if self.approved_amount.to_f > 0
    when "partially_approved"
      raise CustomErrors.new "Approved amount should be less than claim amount" if self.approved_amount.to_f.round(2) >= self.claim_amount.to_f.round(2)
    end
  end

  def validate_claim_ticket_number
    return true if self.claim_ticket_number.blank?
    return true if self.claim_ticket_number.index( /[^[:alnum:]]/ ).blank?
    raise CustomErrors.new "Claim Ticket Number cannot contain special characters"
  end
  
  def get_recovery_percent
    return 0.0 if (self.net_recovery.to_f == 0 || self.benchmark_price.to_f == 0)
    return (self.net_recovery / self.benchmark_price.to_f) * 100
  end
  
  def get_vendor_code
    VendorMaster.find_by_vendor_name(self.responsible_vendor)&.vendor_code
  end
  
end
