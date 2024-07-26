class CreateEWastes < ActiveRecord::Migration[6.0]
  def change
    create_table :e_wastes do |t|
      t.integer :e_waste_order_id
      t.integer :distribution_center_id
      t.integer :inventory_id
      t.integer :client_sku_master_id
      t.string :lot_name
      t.float :mrp
      t.float :map
      t.float :sales_price
      t.integer :client_id
      t.integer :client_category_id
      t.string :client_tag_number
      t.string :serial_number
      t.string :serial_number_2
      t.string :toat_number
      t.float :item_price
      t.string :tag_number
      t.string :sku_code
      t.text :item_description
      t.string :sr_number
      t.string :location
      t.string :brand
      t.string :grade
      t.string :vendor_code
      t.jsonb :details
      t.integer :status_id
      t.string :status
      t.string :aisle_location
      t.datetime :deleted_at

      t.timestamps
    end
    add_index :e_wastes, :inventory_id
    add_index :e_wastes, :distribution_center_id
    add_index :e_wastes, :e_waste_order_id
  end
end
