class CreatePurchaseOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :purchase_orders do |t|
      t.string :order_number
      t.string :customer_name
      t.string :customer_phone
      t.string :customer_email
      t.integer :total_quantity
      t.float :amount
      t.float :tax_amount
      t.integer :discount_percentage
      t.float :total_amount
      t.string :sku_code
      t.string :item_name
      t.float :mrp
      t.float :discounted_price
      t.integer :quantity

      t.timestamps
    end
  end
end
