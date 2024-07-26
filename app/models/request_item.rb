class RequestItem < ApplicationRecord
  belongs_to :put_request
  belongs_to :inventory
  belongs_to :warehouse_order_item, optional: true
  belongs_to :from_sub_location, class_name: "SubLocation", foreign_key: :from_sub_location_id, optional: true
  belongs_to :to_sub_location, class_name: "SubLocation", foreign_key: :to_sub_location_id, optional: true
  
  enum item_type: { item: 1, box: 2, sub_box: 3 }, _prefix: true
  enum status: { pending_pickup: 1, pending_putaway: 2, not_found: 3, wrote_off: 4, location_updated: 5, completed: 6, pending_packaging: 7, cancelled: 8 }, _prefix: true

  validates_presence_of :from_sub_location_id, if: Proc.new { self.put_request.request_type_pick_up? } 
end
