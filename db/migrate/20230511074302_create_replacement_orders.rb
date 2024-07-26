class CreateReplacementOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :replacement_orders do |t|
      t.string :vendor_code
      t.string :order_number
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
