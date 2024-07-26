class Redeploy < ApplicationRecord
  acts_as_paranoid
	belongs_to :distribution_center
  belongs_to :inventory
  has_many :redeploy_histories, dependent: :destroy
  has_many :redeploy_attachments, as: :attachable, dependent: :destroy
  belongs_to :redeploy_order, optional: true
  # after_create :create_history
  # after_update :create_history, :if => Proc.new {|repair| repair.saved_change_to_status_id?}
  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }
  before_save :default_alert_level
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active
  
  def create_history(user_id)
    user = User.find_by_id(user_id)
    status = LookupValue.find(self.status_id)
    self.redeploy_histories.create(status_id: status_id, details: {"pending_redeploy_destination_created_date" => Time.now.to_s, "status_changed_by_user_id" => user.id, "status_changed_by_user_name" => user.full_name } ) if status.original_code == "Pending Redeploy Destination"
    self.redeploy_histories.create(status_id: status_id, details: {"pending_redeploy_dispatch_created_date" => Time.now.to_s, "status_changed_by_user_id" => user.id, "status_changed_by_user_name" => user.full_name  } ) if status.original_code == "Pending Redeploy Dispatch"
  end

  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end
      status = LookupValue.where("original_code = ?", "Pending Redeploy Destination").first
      record                        = self.new
      record.status_id              = status.id
      record.status                 = status.original_code
      record.distribution_center_id = inventory.distribution_center_id
      record.tag_number             = inventory.tag_number
      record.sku_code               = inventory.sku_code
      record.item_description       = inventory.item_description
      record.inventory_id           = inventory.id
      record.details                = inventory.details
      record.details["criticality"] = "Low"
      record.brand                  = inventory.details['brand']
      record.source_code            = inventory.details['source_code']
      record.grade                  = inventory.grade
      record.serial_number          = inventory.serial_number
      record.client_id              = inventory.client_id
      record.client_tag_number      = inventory.client_tag_number
      record.aisle_location         = inventory.aisle_location
      record.toat_number            = inventory.toat_number
      record.item_price             = inventory.item_price
      record.serial_number_2        = inventory.serial_number_2
      record.sr_number              = inventory.sr_number
      record.client_category_id     = inventory.client_category_id
      if record.save
        rh = record.redeploy_histories.new(status_id: record.status_id)
        rh.details = {}
        rh.details["status_changed_by_user_id"] = user.id
        rh.details["status_changed_by_user_name"] = user.full_name
        rh.save
      end
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
  
  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def check_active
    return true if self.inventory.redeploys.where.not(id: self.id).blank?
    return self.inventory.redeploys.where.not(id: self.id).pluck(:is_active).any?(false)
  end
end