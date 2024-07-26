class AddDestinationTypeInWarehouseOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_orders, :destination_type, :string
  end
end
