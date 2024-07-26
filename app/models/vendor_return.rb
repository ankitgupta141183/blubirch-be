class VendorReturn < ApplicationRecord
  acts_as_paranoid
  belongs_to :inventory
  belongs_to :distribution_center
  has_many :vendor_return_histories
  has_many :rtv_alerts
  has_many :rtv_attachments, as: :attachable
  belongs_to :vendor_return_order, optional: true
  before_save :default_alert_level
  # validates_uniqueness_of :tag_number, allow_blank: true, :case_sensitive => false, unless: :check_active

  include JsonUpdateable
  include VendorReturnSearchable
  include Filterable

  scope :filter_by_tag_id, -> (tag_id){ where(tag_number: tag_id) }
  scope :filter_by_brands, -> (brands){ where("details ->> 'brand' IN (?)", brands) }
  scope :filter_by_vendors, -> (vendors){ where("details ->> 'bcl_supplier' IN (?)", vendors) }
  scope :filter_by_approval_code, -> (approval_code){ where("details ->> 'bcl_approval_code' = ?", approval_code) }
  scope :filter_by_inventory_id, -> (inventory_id){ where(sku_code: inventory_id) }

  def self.create_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end
      if inventory.details["work_flow_name"] == 'Flow 4'
        vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
      elsif inventory.details["work_flow_name"] == 'Flow 2'
        vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_brand_inspection)
      else
        vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_claim)
      end

      vendor_return_call_log_id = self.where(tag_number: inventory.tag_number).try(:last).try(:call_log_id)

      record = self.new
      record.inventory_id = inventory.id
      record.tag_number = inventory.tag_number
      record.distribution_center = inventory.distribution_center
      record.grade = inventory.grade
      record.call_log_id = vendor_return_call_log_id
      record.sku_code = inventory.sku_code
      record.item_description = inventory.item_description
      record.item_price = inventory.item_price
      record.details = inventory.details
      record.details["criticality"] = "Low"
      record.status_id = vr_status.id
      record.status = vr_status.original_code
      record.sr_number = inventory.sr_number
      record.serial_number = inventory.serial_number
      record.serial_number2 = inventory.serial_number_2
      record.work_flow_name = inventory.details["work_flow_name"]
      record.aisle_location = inventory.aisle_location
      record.toat_number = inventory.toat_number
      record.client_tag_number = inventory.client_tag_number

      if record.save
        vrh = record.vendor_return_histories.new(status_id: record.status_id)
        vrh.details = {}
        vrh.details['pending_claim_created_at'] = Time.now
        vrh.details["status_changed_by_user_id"] = user.id
        vrh.details["status_changed_by_user_name"] = user.full_name
        vrh.save
      end
    end
  end

  def self.create_rtv_record(inventory, user_id)
    ActiveRecord::Base.transaction do
      if user_id.present?
        user = User.find_by_id(user_id)
      else
        user = inventory.user
      end
      vr_status = LookupValue.find_by_code(Rails.application.credentials.vendor_return_status_pending_dispatch)
      vendor_return_call_log_id = self.where(tag_number: inventory.tag_number).try(:last).try(:call_log_id)
      record = self.new
      record.inventory_id = inventory.id
      record.tag_number = inventory.tag_number
      record.distribution_center = inventory.distribution_center
      record.call_log_id = vendor_return_call_log_id
      record.grade = inventory.grade
      record.sku_code = inventory.sku_code
      record.item_description = inventory.item_description
      record.item_price = inventory.item_price
      record.details = inventory.details
      record.details["criticality"] = "Low"
      record.status_id = vr_status.id
      record.status = vr_status.original_code
      record.sr_number = inventory.sr_number
      record.serial_number = inventory.serial_number
      record.serial_number2 = inventory.serial_number_2
      record.work_flow_name = inventory.details["work_flow_name"]
      record.aisle_location = inventory.aisle_location
      record.toat_number = inventory.toat_number
      record.client_tag_number = inventory.client_tag_number

      if record.save
        vrh = record.vendor_return_histories.new(status_id: record.status_id)
        vrh.details = {}
        vrh.details['pending_dispatch_created_at'] = Time.now
        vrh.details["status_changed_by_user_id"] = user&.id
        vrh.details["status_changed_by_user_name"] = user&.full_name
        vrh.save
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
    if self.inventory.present?
      return true if self.inventory.vendor_returns.where.not(id: self.id).blank?
      return self.inventory.vendor_returns.where.not(id: self.id).where(is_active: true).blank?
    end
  end

  def self.auto_create_dispatch_items
    pending_dispatch_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_dispatch)
    pending_pick_status = LookupValue.find_by_code(Rails.application.credentials.dispatch_status_pending_pick_and_pack)
    warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
    vendor_returns = VendorReturn.includes(:inventory, vendor_return_order: :warehouse_orders).where("vendor_returns.details ->> 'return_date' IS NOT NULL AND status = ?", pending_dispatch_status.original_code)

    vendor_returns.each do |vendor_return|
      next unless vendor_return.details['return_date']&.to_datetime&.past?
      begin
        ActiveRecord::Base.transaction do
          vendor_return_order = vendor_return.update_vendor_return_order(pending_pick_status)
          warehouse_order = vendor_return.update_warehouse_order(warehouse_order_status, vendor_return_order)
          vendor_return.update_warehouse_order_item(warehouse_order_status, warehouse_order)
        end
      rescue StandardError => e
        next
      end
    end
  end

  def update_vendor_return_order(status, vendor_return_order = nil)
    lot_order = "5-#{SecureRandom.hex(4)}"
    vendor_return_order ||= VendorReturnOrder.create!(lot_name: lot_order, order_number: lot_order)
    update_columns({
      vendor_return_order_id: vendor_return_order.id,
      order_number: vendor_return_order.order_number,
      status_id: status.id,
      status: status.original_code
    })

    vendor_return_order
  end

  def update_warehouse_order(status, vendor_return_order)
    vendor_return_order.warehouse_orders.create!({
      distribution_center_id: distribution_center_id,
      reference_number: vendor_return_order.order_number,
      client_id: inventory.client_id,
      status_id: status.id,
      total_quantity: vendor_return_order.vendor_returns.count
    })
  end

  def update_warehouse_order_item(status, warehouse_order)
    client_category = ClientSkuMaster.find_by(code: sku_code)&.client_category
    warehouse_order.warehouse_order_items.create!({
      inventory_id: inventory_id,
      aisle_location: aisle_location,
      toat_number: toat_number,
      sku_master_code: sku_code,
      item_description: item_description,
      tag_number: tag_number,
      quantity: 1,
      status_id: status.id,
      status: status.original_code,
      details: inventory.details,
      serial_number: inventory.serial_number,
      client_category_id: client_category&.id,
      client_category_name: client_category&.name
    })
  end

  def self.move_dispatch_lot
    begin
      task_manager = TaskManager.create_task('VendorReturn.move_dispatch_lot')
      bucket_status = LookupValue.where(code: "dispatch_status_pending_pick_up").last
      warehouse_order_status = LookupValue.find_by_code(Rails.application.credentials.order_status_warehouse_pending_pick)
      
      vendor_return_order_ids = VendorReturn.where("status = 'Pending Dispatch' AND details ->> 'return_date' = ? AND details ->> 'dispatch_started' IS NULL", Date.today.to_s).pluck(:vendor_return_order_id).uniq

      vendor_return_order_ids.each do |vendor_return_order_id|
        vendor_return_order = VendorReturnOrder.find_by(id: vendor_return_order_id)
        vendor_returns = vendor_return_order.vendor_returns

        vendor_returns.update_all(status_id: bucket_status.id, status: bucket_status.original_code)
        vendor_returns.map{|vr|vr.inventory.update_inventory_status!(bucket_status)}

        warehouse_order = vendor_return_order.warehouse_orders.create!(distribution_center_id: vendor_returns.first.distribution_center_id, vendor_code: vendor_return_order.vendor_code, reference_number: vendor_return_order.order_number, client_id: vendor_returns.last.inventory.client_id, status_id: warehouse_order_status.id, total_quantity: vendor_return_order.vendor_returns.count)

        vendor_returns.each do |vr|
          client_category = ClientSkuMaster.find_by_code(vr.sku_code).client_category rescue nil
          warehouse_order.warehouse_order_items.create!(inventory_id: vr.inventory_id, aisle_location: vr.aisle_location, toat_number: vr.toat_number, client_category_id: client_category&.id, client_category_name:  client_category&.name, sku_master_code: vr.sku_code, item_description: vr.item_description, tag_number: vr.tag_number, quantity: 1, status_id: warehouse_order_status.id, status: warehouse_order_status.original_code, details: vr.inventory.details, serial_number: vr.inventory.serial_number)
          vr.update(details: vr.details.merge!({'dispatch_started': 'Completed'}))
        end
      end
      task_manager.complete_task
    rescue => exception
      task_manager.complete_task(exception)
    end
  end
end
