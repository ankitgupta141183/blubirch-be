class CreateOndcOrderItems < ActiveRecord::Migration[6.0]
  def change
    create_table :ondc_order_items do |t|
      t.integer :ondc_order_id
      t.integer :inventory_id
      t.float :quantity
      t.float :price
      t.string :fulfillment_number
      t.timestamps
    end
  end
end
