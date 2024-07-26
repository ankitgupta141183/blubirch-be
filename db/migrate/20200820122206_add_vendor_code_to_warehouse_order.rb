class AddVendorCodeToWarehouseOrder < ActiveRecord::Migration[6.0]
  def change
  	add_column :warehouse_orders, :vendor_code, :string
  end
end
