class CreatePosInvoices < ActiveRecord::Migration[6.0]
  def change
    create_table :pos_invoices do |t|
      t.string :invoice_number
      t.string :customer_name
      t.string :customer_phone
      t.string :customer_email
      t.string :customer_code
      t.string :customer_location
      t.integer :total_quantity
      t.float :amount
      t.float :tax_amount
      t.integer :discount_percentage
      t.integer :applied_coupon_code
      t.float :total_amount
      t.string :sku_code
      t.string :item_name
      t.float :mrp
      t.float :discounted_price
      t.integer :quantity
      t.string :invoice_type

      t.timestamps
    end
  end
end
