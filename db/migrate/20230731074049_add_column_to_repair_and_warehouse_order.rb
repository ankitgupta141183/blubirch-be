class AddColumnToRepairAndWarehouseOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :repairs, :vendor_name, :string
    add_column :warehouse_orders, :vendor_name, :string
  end
end
