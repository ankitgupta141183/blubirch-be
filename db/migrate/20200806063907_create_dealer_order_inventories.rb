class CreateDealerOrderInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :dealer_order_inventories do |t|
      t.integer :dealer_order_id
      t.integer :dealer_id
      t.float :mrp
      t.integer :client_sku_master_id
      t.string :serail_number
      t.string :sku_master_code
      t.string :item_description
      t.float :unit_price
      t.integer :quantity
      t.integer :dispatched_quantity
      t.integer :received_quantity
      t.integer :status_id
      t.string :status
      t.integer :sale_status_id
      t.string :sale_status
      t.string :invoice_number
      t.datetime :deleted_at
      t.timestamps
    end
  end
end
