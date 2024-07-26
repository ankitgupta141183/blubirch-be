class CreateProductions < ActiveRecord::Migration[6.0]
  def change
    create_table :productions do |t|
      t.references :distribution_center
      t.references :forward_inventory
      t.references :client_sku_master
      t.string :tag_number
      t.string :sku_code
      t.string :item_description
      t.string :grade
      t.string :supplier
      t.string :serial_number
      t.string :uom
      t.integer :uom_id
      t.integer :quantity
      t.string :sku_type
      t.integer :sku_type_id
      t.integer :status_id
      t.string :status
      t.string :box_number
      t.jsonb :details
      t.float :item_price
      t.date :inwarded_date
      t.boolean :is_active, default: true
      t.string :ancestry
      t.index :ancestry
      t.datetime :deleted_at

      t.timestamps
    end
  end
end
