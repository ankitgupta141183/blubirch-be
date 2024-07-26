class AddFieldsToWarehouseOrderItems < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :dispatch_box_id, :integer
    add_column :warehouse_order_items, :destination_type, :string
    add_column :warehouse_order_items, :orrd, :string
    add_column :warehouse_order_items, :reject_reason, :integer
  end
end
