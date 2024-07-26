class CreateOndcOrderFulfillments < ActiveRecord::Migration[6.0]
  def change
    create_table :ondc_order_fulfillments do |t|
      t.integer :ondc_order_id
      t.string :fulfillment_number
      t.string :fulfillment_type
      t.boolean :tracking
      t.jsonb :customer_details 
      t.jsonb :store_details
      t.timestamps
    end
  end
end
