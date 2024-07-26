class CreateInsuranceOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :insurance_orders do |t|

      t.string :order_number
      t.string :vendor_code
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
