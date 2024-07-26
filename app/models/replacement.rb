class Replacement < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory
  belongs_to :distribution_center
  belongs_to :replacement_order, optional: true

  has_many :replacement_histories
  has_many :replacement_attachments, as: :attachable

  before_save :default_alert_level

  enum return_method: { dispatch: 1, handover: 2 }, _prefix: true
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active

  before_save do
    true if self.vendor.present?
    if self.vendor.blank? && self.inventory.vendor_code.present?
      self.vendor = self.inventory.vendor_code
      self.vendor_name = VendorMaster.find_by_vendor_code(self.vendor).vendor_name
    end
    if self.vendor.present? && self.vendor_name.blank?
      self.vendor_name = VendorMaster.find_by_vendor_code(self.vendor).vendor_name
    end
  end

  def vendor_code
    return self.vendor
  end

  def self.create_record(inventory, user_id)
    if user_id.present?
      user = User.find_by_id(user_id)
    else
      user = inventory.user
    end
    replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_confirmation)
    record = Replacement.new
    record.inventory = inventory
    record.tag_number = inventory.tag_number
    record.distribution_center = inventory.distribution_center
    record.grade = inventory.grade
    record.sku_code = inventory.sku_code
    record.item_description = inventory.item_description
    record.item_price = inventory.item_price
    record.details = inventory.details
    record.details["criticality"] = "Low"
    record.status_id = replacement_status.id
    record.status = replacement_status.original_code
    record.serial_number = inventory.serial_number
    record.serial_number_2 = inventory.serial_number_2
    record.aisle_location = inventory.aisle_location
    record.toat_number = inventory.toat_number
    record.client_tag_number = inventory.client_tag_number
    record.approval_code = inventory.details['bcl_approval_code']
    record.vendor = inventory.details['vendor_code']

    if record.save
      rh = record.replacement_histories.new(status_id: record.status_id)
      rh.details = {}
      rh.details['pending_replacement_approved_created_at'] = Time.now
      rh.details["status_changed_by_user_id"] = user&.id
      rh.details["status_changed_by_user_name"] = user&.full_name
      rh.save
    end
  end

  def self.set_manual_disposition(vendor_return, user_id)
    vendor_return = vendor_return
    inventory = vendor_return.inventory
    if user_id.present?
      user = User.find_by_id(user_id)
    else
      user = inventory.user
    end
    replacement_status = LookupValue.find_by_code(Rails.application.credentials.replacement_status_pending_confirmation)
    record = self.new
    record.inventory = inventory
    record.tag_number = inventory.tag_number
    record.distribution_center = inventory.distribution_center
    record.grade = inventory.grade
    record.sku_code = inventory.sku_code
    record.item_description = inventory.item_description
    record.item_price = inventory.item_price
    record.details = inventory.details
    record.status_id = replacement_status.id
    record.status = replacement_status.original_code
    record.serial_number = inventory.serial_number
    record.call_log_id = vendor_return.call_log_id
    record.call_log_date = vendor_return.created_at
    record.replacement_location = vendor_return.try(:inspection_replacement_location)
    replacement_location = LookupValue.find_by_original_code(record.replacement_location)
    record.replacement_location_id = replacement_location&.id
    record.rgp_number = vendor_return.try(:inspection_rgp_number)
    record.replacement_date = vendor_return.try(:brand_inspection_date)
    record.replacement_remark = vendor_return.try(:brand_inspection_remarks)
    record.aisle_location = inventory.aisle_location
    record.toat_number = vendor_return.toat_number

    if record.save
      rh = record.replacement_histories.new(status_id: record.status_id)
      rh.details = {}
      key = "#{record.status.try(:downcase).try(:strip).split(' ').join('_')}_created_at"
      rh.details[key] = Time.now
      rh.details["status_changed_by_user_id"] = user.id
      rh.details["status_changed_by_user_name"] = user.full_name
      rh.save
    end
  end

  def default_alert_level
    if status_changed? || status_id_changed?
      self.details['criticality'] = 'Low'
    end
  end

  def create_history(user_id=nil)
    if user_id.present?
      user = User.find_by_id(user_id) 
    else
      user = User.find_by_id(self.inventory.user_id) 
    end
    status_d = LookupValue.find(self.status_id)
    details_key = status_d.original_code.downcase.split(" ").join("_") + "_created_date"
    self.replacement_histories.create(status_id: status_d.id, details: {details_key => Time.now.to_s, "status_changed_by_user_id" => user&.id, "status_changed_by_user_name" => user&.full_name } )
  end

  def call_log_or_claim_date
    self.call_log_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  #! Replacement.send_items_to_dispatch
  def self.send_items_to_dispatch
    replacements = self.where("is_confirmed = true AND status = 'Pending Confirmation' AND return_date < ?", (Date.current + 7.days).to_date)
    return "No Replacements records" if replacements.blank?
    item_count = replacements.count
    ActiveRecord::Base.transaction do
      replacement_order = ReplacementOrder.new(vendor_code: replacements.first.vendor_code)
      replacement_order.order_number = "OR-Replacement-#{SecureRandom.hex(6)}"
      replacement_order.save!
  
      next_status = LookupValue.find_by(code: Rails.application.credentials.replacement_status_dispatch).original_code
      next_status_id = LookupValue.find_by(original_code: next_status).try(:id)
      replacements.update_all(replacement_order_id: replacement_order.id, status: next_status, status_id: next_status_id)
    
      warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_pickup)
      warehouse_order = replacement_order.warehouse_orders.new(
        distribution_center_id: replacements.first.distribution_center_id, 
        vendor_code: replacement_order.vendor_code, 
        reference_number: replacement_order.order_number,
        client_id: replacements.last.client_id,
        status_id: warehouse_order_status.id,
        total_quantity: replacement_order.replacements.count
      )
      warehouse_order.save!
  
      replacement_order.replacements.each do |replacement|
        #& Creating replacement history
        replacement.create_history(nil)
        #repair.update_inventory_status(next_status)
        
        client_category = ClientSkuMaster.find_by_code(replacement.sku_code).client_category rescue nil
        warehouse_order_item = warehouse_order.warehouse_order_items.new(
          inventory_id: replacement.inventory_id,
          client_category_id: (client_category.id rescue nil),
          client_category_name: (client_category.name rescue nil),
          sku_master_code: replacement.sku_code,
          item_description: replacement.item_description,
          tag_number: replacement.tag_number,
          quantity: 1,
          status_id: warehouse_order_status.id,
          status: warehouse_order_status.original_code,
          serial_number: replacement.serial_number,
          aisle_location: replacement.aisle_location,
          toat_number: replacement.toat_number,
          details: replacement.inventory.details
        )
        warehouse_order_item.save!
      end
      return "#{item_count} item(s) sent to dispatch"
    end
  end

  def visit_date
    self.replacement_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def resolution_date_time
    self.resolution_date.to_date.strftime("%d/%b/%Y") rescue ''
  end

  def self.get_existing_call_log_date
    Replacement.all.each do |r|
      vendor_return = r.inventory.vendor_return
      if vendor_return.present?
        r.call_log_date = vendor_return.created_at
        #get approved and resolution date
        st = LookupValue.where(code: Rails.application.credentials.vendor_return_status_pending_disposition).last
        vrh = vendor_return.vendor_return_histories.where(status_id: st.id).last
        r.resolution_date = vrh.details['pending_dispatch_created_at'] if vrh.present?
        r.save
      end
    end

    Insurance.all.each do |r|
      sts = LookupValue.where(code: [LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_dispatch).code, LookupValue.find_by_code(Rails.application.credentials.insurance_status_pending_insurance_disposition).code])
      vrh = r.insurance_histories.where(status_id: sts.pluck(:id)).last
      r.resolution_date = vrh.created_at if vrh.present?
      r.save
    end

    Repair.all.each do |r|
      sts = LookupValue.where(code: [LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_grade).code, LookupValue.find_by(code: Rails.application.credentials.repair_status_pending_repair_disposition).code])
      vrh = r.repair_histories.where(status_id: sts.pluck(:id)).last
      r.resolution_date = vrh.created_at if vrh.present?
      r.save
    end

    VendorReturn.all.each do |r|
      sts = LookupValue.where(code: [LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch).code, LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_disposition).code])
      vrh = r.vendor_return_histories.where(status_id: sts.pluck(:id)).last
      r.resolution_date = vrh.details['pending_dispatch_created_at'] if vrh.present?
      r.save
    end
  end

  def check_active
    return true if self.inventory.replacements.where.not(id: self.id).blank?
    return self.inventory.replacements.where.not(id: self.id).where(is_active: true).blank?
  end
end
