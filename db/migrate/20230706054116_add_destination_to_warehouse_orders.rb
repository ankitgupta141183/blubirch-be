class AddDestinationToWarehouseOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_orders, :destination, :string
    add_column :warehouse_order_items, :destination, :string
  end
end
