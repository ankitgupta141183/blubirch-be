class AddStatusToWarehouseOrderItem < ActiveRecord::Migration[6.0]
  def change
  	add_column :warehouse_order_items, :status, :string
  end
end
