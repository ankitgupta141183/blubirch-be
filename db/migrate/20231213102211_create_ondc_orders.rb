class CreateOndcOrders < ActiveRecord::Migration[6.0]
  #user_name - String
  #user_address - JSON 
  #user_phone - String
  #user_email - String
  #order_number - String
  #order_state - String
  #client_id - ref
  #distribution_center_id - ref
  #price - String
  #currency - String
  #quote_breakup - JSON
  #tags - JSON
  #ttl - String
  def change
    create_table :ondc_orders do |t|
      t.string :user_name
      t.jsonb :user_address 
      t.string :user_phone
      t.string :user_email
      t.string :order_number
      t.string :order_state
      t.integer :client_id
      t.integer :distribution_center_id
      t.string :amount
      t.string :currency
      t.jsonb :quote_breakup
      t.text :tags, array: true
      t.string :ttl
      t.string :cancellation_reason_id
      t.timestamps
    end
  end
end
