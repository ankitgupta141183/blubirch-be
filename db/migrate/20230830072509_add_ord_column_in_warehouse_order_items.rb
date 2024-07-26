class AddOrdColumnInWarehouseOrderItems < ActiveRecord::Migration[6.0]
  def change
    add_column :warehouse_order_items, :ord, :string
  end
end
