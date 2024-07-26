class CreateOutwardReturnOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :outward_return_orders do |t|
      t.string :vendor_code
      t.string :order_number

      t.timestamps
    end
  end
end
