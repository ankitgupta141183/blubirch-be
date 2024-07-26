class AddInventoryTypeToWarehouseOrderItem < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :inventory_type, :string, default: 'Inventory'
  end
end
