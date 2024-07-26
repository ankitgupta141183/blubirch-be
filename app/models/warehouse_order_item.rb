class WarehouseOrderItem < ApplicationRecord
	acts_as_paranoid
  belongs_to :warehouse_order
  belongs_to :inventory, optional: true
  belongs_to :forward_inventory, optional: true
	belongs_to :dispatch_box, optional: true
  has_many :request_items

	validates_uniqueness_of :inventory_id, scope: [:tab_status], if: Proc.new { !self.tab_status_dispatched? }, allow_nil: true

  enum dispatch_request_status: { to_be_created: 1, pending: 2 }, _prefix: true
  enum tab_status: { pending_pickup: 1, pending_packaging: 2, pending_dispatch: 3, pending_disposition: 4, not_found_items: 5, dispatched: 6 }, _prefix: true
	enum reject_reason: { item_mismatch: 1, condition_mismatch: 2, no_reason: 3 }, _prefix: true
  enum item_status: { open: 1, closed: 2 }, _prefix: true

  before_save :set_destination_type, if: Proc.new { self.destination_type.blank? }
  after_save :set_warehouse_order_status, if: Proc.new { self.warehouse_order.orderable_type == 'LiquidationOrder' }

  after_create do 
    bucket_status = LookupValue.where(code: "dispatch_status_pending_pick_up").last
    # self.inventory.update_inventory_status!(bucket_status, Current.user&.id)
    if self.forward_inventory_id.present?
      self.forward_inventory.update!(disposition: 'Dispatch', status_id: bucket_status.id, status: bucket_status.original_code)
      self.forward_inventory.update_inventory_status(bucket_status, Current.user&.id)
    else
      self.inventory.update!(disposition: 'Dispatch', status_id: bucket_status.id, status: bucket_status.original_code)
      self.inventory.update_inventory_status!(bucket_status, Current.user&.id)
    end
  end

  before_create do
    self.item_status = :open
    self.is_active = true
    self.tab_status = :pending_pickup
    self.dispatch_request_status = :to_be_created
  end

  # Adding this method for managain forward and reverse warehouse_order_items at same places
  # comming code as query adding based on diff.joins, in single join not possible
  # def self.joins_forward_and_reverse_inventory
  #   # joins(
  #   #   "LEFT JOIN inventories ON inventories.id = warehouse_order_items.inventory_id"
  #   # ).joins(
  #   #   "LEFT JOIN forward_inventories ON forward_inventories.id = warehouse_order_items.forward_inventory_id"
  #   # ).where("warehouse_order_items.inventory_id IS NOT NULL OR warehouse_order_items.forward_inventory_id IS NOT NULL")
  #   left_joins(:inventory, :forward_inventory).where("warehouse_order_items.inventory_id IS NOT NULL OR warehouse_order_items.forward_inventory_id IS NOT NULL")
  # end
  
  # def self.put_away_joins
  #   left_outer_joins(inventory: :sub_location, forward_inventory: :sub_location).where("warehouse_order_items.inventory_id IS NOT NULL OR warehouse_order_items.forward_inventory_id IS NOT NULL")
  # end

  # def self.query_forward_and_reverse_distribustion_center(distribution_center_ids)
  #   where('inventories.distribution_center_id IN (?) OR forward_inventories.distribution_center_id IN (?)', distribution_center_ids, distribution_center_ids)
  # end

  def tab_status_to_status
    {
      "pending_pickup": "Pending Pick-Up",
      "pending_packaging": "Pending Packaging",
      "pending_dispatch": "Pending Dispatch",
      "pending_disposition": "Pending Disposition",
      "dispatched": "Dispatched"
    }
  end

  def set_disposition(disposition, current_user = nil)
    raise CustomErrors.new "Disposition can't be blank!" if disposition.blank?
    
    inventory = self.inventory
    self.is_active = false
		self.item_status = :closed
    self.save!
		
		inventory.disposition = disposition
    inventory.save!
    DispositionRule.create_bucket_record(disposition, inventory, 'WarehouseOrderItem', current_user&.id)
  end

  def set_destination_type
    order = self.warehouse_order
    self.destination = order.destination
    self.destination_type = order.destination_type
    self.orrd = order.reference_number
  end

  def set_warehouse_order_status
    if saved_change_to_tab_status?
      statuses = self.warehouse_order.warehouse_order_items.pluck(:tab_status).uniq
      status_id = if statuses.include?('pending_pickup')
        LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pick).id
      elsif statuses.include?('pending_packaging')
        LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_pack).id
      elsif statuses.include?('pending_dispatch')
        LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_pending_dispatch).id
      else
        LookupValue.find_by(code: Rails.application.credentials.order_status_warehouse_in_dispatch).id
      end  
      self.warehouse_order.update(status_id: status_id)
    end
  end
end
