class AddOrrdToWarehouseOrders < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_orders, :orrd, :string
  end
end
