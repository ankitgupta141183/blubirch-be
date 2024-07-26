class CreateReturnInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :return_inventories do |t|
      t.integer :inventory_id
      t.string :tag_number
      t.string :sku_code
      t.string :serial_number
      t.text :images, array: true, default: []
      t.timestamps
    end
  end
end
