class CreateOndcOrderPayments < ActiveRecord::Migration[6.0]
  def change
    create_table :ondc_order_payments do |t|
      t.integer :ondc_order_id
      t.string :currency
      t.string :transaction_number 
      t.float :amount
      t.string :status
      t.string :order_type
      t.string :collected_by
      t.jsonb :details
      t.timestamps
    end
  end
end
