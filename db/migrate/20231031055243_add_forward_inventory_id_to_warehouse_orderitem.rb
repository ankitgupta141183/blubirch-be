class AddForwardInventoryIdToWarehouseOrderitem < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :forward_inventory_id, :integer
  end
end
