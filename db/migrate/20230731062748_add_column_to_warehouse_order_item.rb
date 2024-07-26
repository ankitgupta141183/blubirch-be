class AddColumnToWarehouseOrderItem < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :amount, :decimal
  end
end
