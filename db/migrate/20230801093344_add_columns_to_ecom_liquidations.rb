class AddColumnsToEcomLiquidations < ActiveRecord::Migration[6.0]
  def change
    add_column :ecom_liquidations, :order_number, :string
    add_column :ecom_liquidations, :vendor_code, :string
    add_column :ecom_liquidations, :vendor_name, :string
  end
end
