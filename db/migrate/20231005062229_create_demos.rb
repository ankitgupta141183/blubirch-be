class CreateDemos < ActiveRecord::Migration[6.0]
  def change
    create_table :demos do |t|
      t.references :distribution_center
      t.references :forward_inventory
      t.references :client_sku_master
      t.string :tag_number
      t.string :sku_code
      t.string :item_description
      t.string :grade
      t.string :supplier
      t.string :serial_number
      t.integer :status_id
      t.string :status
      t.jsonb :details
      t.float :item_price
      t.integer :quantity
      t.boolean :is_active, default: true
      t.integer :transfer_location_id
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
