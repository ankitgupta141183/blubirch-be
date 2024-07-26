class CreateWarehouseOrderItems < ActiveRecord::Migration[6.0]
  def change
    create_table :warehouse_order_items do |t|
      t.integer :warehouse_order_id
      t.integer :inventory_id
      t.integer :client_category_id
      t.string :client_category_name
      t.string :sku_master_code
      t.string :item_description
      t.string :tag_number
      t.string :serial_number
      t.string :aisle_location
      t.integer :quantity
      t.string :toat_number
      t.jsonb :details
      t.integer :status_id
      t.string :packaging_box_number
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :warehouse_order_items, :inventory_id
    add_index :warehouse_order_items, :client_category_id
  end
end
