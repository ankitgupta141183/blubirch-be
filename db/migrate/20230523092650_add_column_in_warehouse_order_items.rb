class AddColumnInWarehouseOrderItems < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :dispatch_request_status, :integer
    add_column :warehouse_order_items, :tab_status, :integer 
  end
end
