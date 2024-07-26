class PutRequest < ApplicationRecord
  acts_as_paranoid
  belongs_to :distribution_center
  # belongs_to :assignee, class_name: "User", foreign_key: :assignee_id
  has_many :request_items
  has_many :user_requests
  has_many :users, through: :user_requests
  
  # validations
  validates_presence_of :request_type  # request_id
  
  # callbacks
  after_create :generate_request_id
  
  # enums & constants
  enum request_type: { put_away: 1, pick_up: 2, packaging: 3 }, _prefix: true
  enum put_away_reason: { inward_putaway: 1, open_putaway: 2 }, _prefix: true
  enum pick_up_reason: { movement: 1, dispatch: 2, repair: 3, inspection: 4, sampling: 5, grading: 6, other: 7, packaging: 8 }, _prefix: true
  enum status: { pending: 1, in_progress: 2, completed: 3, cancelled: 4 }, _prefix: true
  
  # scopes
  scope :search_by_request_id, -> (request_id) { where("request_id ilike ?", "%#{request_id}%")}
  scope :putaway_requests, -> { where(is_dispatch_item: false) }
  scope :dispatch_requests, -> { where(is_dispatch_item: true) }
  
  def generate_request_id
    req_id = "P-1" + "%04d" % self.id
    self.request_id = req_id
    self.save!
  end
  
  def assign_users(user_ids)
    raise CustomErrors.new "Please select Assignee" if user_ids.blank?
    existing_user_ids = self.users.pluck(:id)
    users = self.distribution_center.users.where(id: user_ids)
    users.each do |user|
      user_request = self.user_requests.find_or_initialize_by(user_id: user.id)
      user_request.save!
    end
    removed_ids = existing_user_ids - user_ids
    self.user_requests.where(user_id: removed_ids).destroy_all
  end
  
  def update_request_items(inventory_ids: [], warehouse_order_item_ids: [], from_dispatch: false)
    if from_dispatch
      warehouse_order_items = WarehouseOrderItem.where(id: warehouse_order_item_ids)
      existing_item_ids = self.request_items.pluck(:warehouse_order_item_id)
      raise CustomErrors.new "Outward Reason Ref Order should be same for all items." if (warehouse_order_items.pluck(:orrd).compact.uniq.count > 1)
      
      warehouse_order_items.each_with_index do |wo_item, i|
        request_item = self.request_items.find_or_initialize_by(warehouse_order_item_id: wo_item.id, item_type: "item")
        request_item.inventory_id = wo_item.inventory_id
        request_item.from_sub_location_id = request_item.inventory.sub_location_id
        request_item.status = self.request_type_pick_up? ? :pending_pickup : :pending_packaging
        request_item.sequence = i+1
        request_item.save!
        
        wo_item.update!(dispatch_request_status: :pending)
      end
      removed_ids = existing_item_ids - warehouse_order_item_ids
      removed_items = WarehouseOrderItem.where(id: removed_ids)
      removed_items.update_all(dispatch_request_status: :to_be_created)
      self.request_items.where(warehouse_order_item_id: removed_ids).destroy_all
    else
      inventories = self.distribution_center.inventories.where(id: inventory_ids)
      existing_inventory_ids = self.request_items.pluck(:inventory_id)
      
      inventories.each_with_index do |inventory, i|
        raise CustomErrors.new "Item #{inventory.tag_number} is already inwarded!" if self.put_away_reason_inward_putaway? && inventory.is_putaway_inwarded?
        
        request_item = self.request_items.find_or_initialize_by(inventory_id: inventory.id, item_type: "item")
        request_item.from_sub_location_id = inventory.sub_location_id
        request_item.status = self.request_type_pick_up? ? :pending_pickup : :pending_putaway
        request_item.sequence = i+1
        request_item.save!
      end
      removed_ids = existing_inventory_ids - inventory_ids
      self.request_items.where(inventory_id: removed_ids).destroy_all
    end
  end
  
  def get_items_and_boxes
    data = []
    status_ids = self.is_dispatch_item? ? [1,2,7] : [1,2]
    all_items = self.request_items.includes(inventory: :gate_pass).where(status: status_ids).order(sequence: :asc)
    items = all_items.where(box_no: nil)
    box_nos = all_items.where.not(box_no: nil).pluck(:box_no).uniq.compact
    items.each do |item|
      inventory = item.inventory
      item_data = {id: item.id, inventory_id: item.inventory_id, tag_number: inventory.tag_number, status: item.status, item_type: "item", obd_number: inventory.gate_pass&.client_gatepass_number }
      item_data[:sub_location] = inventory.sub_location&.code if self.request_type_pick_up?
      data << item_data
    end
    box_nos.each do |box_no|
      status = all_items.where(box_no: box_no).last.status
      box_data = {item_type: "box", box_no: box_no, status: status}
      box_data[:items] = self.request_items.joins(:inventory).where(box_no: box_no).pluck(:"inventories.tag_number") if self.is_dispatch_item?
      data << box_data
    end
    data
  end
  
  def update_cancelled_items
    request_items.each do |request_item|
      request_item.warehouse_order_item.update(dispatch_request_status: :to_be_created) if self.is_dispatch_item?
      request_item.update!(status: :cancelled)
    end
  end
end
