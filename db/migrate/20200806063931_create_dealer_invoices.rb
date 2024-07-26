class CreateDealerInvoices < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_invoices do |t|
      t.integer :dealer_id
      t.integer :dealer_customer_id
      t.string :customer_code
      t.string :customer_name
      t.string :customer_phone_number
      t.string :customer_email
      t.string :customer_company_name
      t.string :customer_address_1
      t.string :customer_address_2
      t.string :customer_city
      t.string :customer_state
      t.string :customer_country
      t.string :customer_pincode
      t.string :customer_gst
      t.string :dealer_company_name
      t.string :dealer_address_1
      t.string :dealer_address_2
      t.string :dealer_city
      t.string :dealer_state
      t.string :dealer_country
      t.string :dealer_pincode
      t.string :dealer_gst
      t.string :dealer_pan
      t.string :dealer_cin
      t.integer :quantity
      t.float :total_amount
      t.float :discount_percentage
      t.float :discount_amount
      t.float :tax_amount
      t.float :amount
      t.string :invoice_number
      t.integer :status_id
      t.string :status
      t.integer :user_id
      t.integer :payment_mode_id
      t.string :payment_mode
      t.string :payment_id_proof_number
      t.integer :coupon_id
      t.string :coupon_code
      t.float :coupon_discount_percentage
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
