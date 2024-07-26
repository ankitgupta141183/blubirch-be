class CreateSaleOrders < ActiveRecord::Migration[6.0]
  #vendor_code
  #order_number
  def change
    create_table :sale_orders do |t|
      t.string :vendor_code
      t.string :order_number
      t.timestamps
    end
  end
end
