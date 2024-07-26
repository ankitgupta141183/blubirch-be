class AddNewColumnToOrder < ActiveRecord::Migration[6.0]
  def change
    add_column :vendor_return_orders, :lot_name, :string
    add_column :redeploy_orders, :lot_name, :string
  end
end
