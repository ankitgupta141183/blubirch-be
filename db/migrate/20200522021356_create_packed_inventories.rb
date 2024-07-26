class CreatePackedInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :packed_inventories do |t|
    	t.integer :packaging_box_id
			t.integer :inventory_id
			t.integer :user_id
			t.datetime :deleted_at

      t.timestamps
    end
    add_index :packed_inventories, :packaging_box_id
    add_index :packed_inventories, :inventory_id
    add_index :packed_inventories, :user_id
  end
end
