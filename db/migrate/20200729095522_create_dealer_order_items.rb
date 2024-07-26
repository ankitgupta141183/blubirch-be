class CreateDealerOrderItems < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_order_items do |t|
      t.integer :dealer_order_id
      t.float :mrp
      t.integer :client_sku_master_id
      t.string :sku_master_code
      t.string :item_description
      t.float :discount_percentage
      t.float :discount_price
      t.float :unit_price
      t.integer :quantity
      t.integer :dispatched_quantity
      t.integer :received_quantity
      t.integer :processed_quantity
      t.float :processed_discount_price
      t.float :processed_discount_percentage
      t.float :total_amount
      t.datetime :deleated_at
      t.timestamps
    end
    add_index :dealer_order_items, :dealer_order_id
    add_index :dealer_order_items, :client_sku_master_id
  end
end
