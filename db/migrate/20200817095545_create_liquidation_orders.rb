class CreateLiquidationOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :liquidation_orders do |t|
    	t.string :order_number
    	t.string :vendor_code
    	t.float :order_amount
    	t.datetime :deleted_at
    	t.timestamps
    end
  end
end
