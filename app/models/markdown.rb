class Markdown < ApplicationRecord

  include MarkdownSearchable
  include Filterable

  acts_as_paranoid
	belongs_to :inventory
  belongs_to :distribution_center
  belongs_to :markdown_order, optional: true

  has_many :markdown_histories
  has_many :markdown_attachments, as: :attachable
  scope :dc_filter, ->(center_ids) { where(distribution_center_id: center_ids) }
  scope :filter_by_tag_id, -> (tag_id){ where(tag_number: tag_id) }
  scope :filter_by_asp, -> (asp){ where("asp between ? AND ?", asp['min'], asp['max']) }
  scope :filter_by_category, -> (categories){ where("client_category_id in (?)", categories) }
  scope :filter_by_grade, -> (grades){ where("grade in (?)", grades) }
  before_save :default_alert_level
  # validates_uniqueness_of :tag_number, :case_sensitive => false, allow_blank: true, unless: :check_active

  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end
      status = LookupValue.find_by_code(Rails.application.credentials.markdown_status_pending_markdown_destination)
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
      record.client_id = inventory.client_id
      record.client_tag_number = inventory.client_tag_number
      record.serial_number = inventory.serial_number
      record.toat_number = inventory.toat_number
      record.aisle_location = inventory.aisle_location
      record.item_price = inventory.item_price
      record.serial_number_2 = inventory.serial_number_2
      record.brand = inventory.details["brand"]
      record.client_category_id = inventory.client_category_id
      record.asp = inventory.details["asp"]

      if record.save
        ih = record.markdown_histories.new(status_id: record.status_id)
        ih.details = {}
        ih.details['pending_markdown_destination_created_at'] = Time.now.to_s
        ih.details["status_changed_by_user_id"] = user.id
        ih.details["status_changed_by_user_name"] = user.full_name
        ih.save
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
    return true if self.inventory.markdowns.where.not(id: self.id).blank?
    return self.inventory.markdowns.where.not(id: self.id).where(is_active: true).blank?
  end
end
