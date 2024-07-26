class RemoveInventoryTypeFromWarehouseOrderItem < ActiveRecord::Migration[6.0]
  def change
    remove_column :warehouse_order_items, :inventory_type, :string
  end
end
