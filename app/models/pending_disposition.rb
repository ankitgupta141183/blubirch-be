class PendingDisposition < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory
  belongs_to :distribution_center
  has_many :pending_disposition_histories
  before_save :default_alert_level

  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active


  def self.create_record(inventory, user_id=nil)
    ActiveRecord::Base.transaction do
      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end
      status = LookupValue.find_by_code(Rails.application.credentials.pending_disposition_status_pending_disposition)
      record = self.new
      record.inventory_id = inventory.id
      record.tag_number = inventory.tag_number
      record.distribution_center = inventory.distribution_center
      record.grade = inventory.grade
      record.sku_code = inventory.sku_code
      record.item_description = inventory.item_description
      record.sr_number = inventory.sr_number
      record.details = inventory.details
      record.details["criticality"] = "Low"
      record.status_id = status.id
      record.status = status.original_code
      record.details["serial_number"] = inventory.serial_number
      record.serial_number = inventory.serial_number
      record.serial_number_2 = inventory.serial_number_2
      record.aisle_location = inventory.aisle_location
      record.client_tag_number = inventory.client_tag_number
      record.gate_pass_id = inventory.gate_pass_id
      record.client_id = inventory.client_id
      record.return_reason = inventory.return_reason
      record.toat_number = inventory.toat_number
      if record.save
        pdh = record.pending_disposition_histories.new(status_id: record.status_id)
        pdh.details = {}
        pdh.details["status_changed_by_user_id"] = user.id
        pdh.details["status_changed_by_user_name"] = user.full_name
        pdh.save
      end
    end
  end

  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def check_active
    if self.inventory.present?
    return true if self.inventory.pending_dispositions.where.not(id: self.id).blank?
    return self.inventory.pending_dispositions.where.not(id: self.id).where(is_active: true).blank?
    end
  end

  def call_log_or_claim_date
    self.claim_email_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def visit_date
    self.brand_inspection_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def resolution_date_time
    self.resolution_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

end
