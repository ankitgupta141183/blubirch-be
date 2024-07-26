class CreateLeaseOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :lease_orders do |t|
      t.string :vendor_code
      t.string :order_number
      t.date :lease_start_date
      t.date :lease_end_date
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
