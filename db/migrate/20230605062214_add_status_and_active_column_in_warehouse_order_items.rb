class AddStatusAndActiveColumnInWarehouseOrderItems < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :item_status, :integer, :default => WarehouseOrderItem.item_statuses['open']
    add_column :warehouse_order_items, :is_active, :boolean, :default => true
  end
end
