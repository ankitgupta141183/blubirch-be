class CreateBackOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :back_orders do |t|
      t.string :vender_code
      t.string :order_number
      t.timestamps
    end
  end
end
