class CreateVendorReturnOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :vendor_return_orders do |t|

      t.string :name
      t.string :order_number
      t.string :vendor_code
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
