class CreateRestocks < ActiveRecord::Migration[6.0]
  def change
    create_table :restocks do |t|
      t.integer :distribution_center_id
      t.integer :inventory_id
      t.string :tag_number
      t.string :sku_code
      t.text :item_description
      t.string :source_code
      t.string :destination_code
      t.jsonb :details
      t.integer :status_id
      t.text :pending_destination_remarks
      t.string :status
      t.string :sr_number
      t.string :brand
      t.string :grade
      t.string :serial_number
      t.datetime :deleted_at
      t.string :vendor
      t.integer :transfer_order_id
      t.integer :client_id
      t.string :client_tag_number
      t.string :toat_number
      t.string :aisle_location
      t.float :item_price
      t.string :serial_number_2
      t.integer :client_category_id
      t.boolean :is_active, :default => false
      t.timestamps
    end
  end
end
