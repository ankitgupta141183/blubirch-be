class CreateGatePassInventories < ActiveRecord::Migration[6.0]
  def change
    create_table :gate_pass_inventories do |t|
      t.integer :distribution_center_id
      t.integer :client_id
      t.integer :user_id
      t.integer :gate_pass_id
      t.integer :client_category_id
      t.string :client_category_name
      t.string :sku_code
      t.string :item_description
      t.integer :quantity
      t.integer :inwarded_quantity
      t.float :map

      t.datetime :deleted_at
      t.timestamps
    end
    add_index :gate_pass_inventories, :distribution_center_id
    add_index :gate_pass_inventories, :client_id
    add_index :gate_pass_inventories, :user_id
    add_index :gate_pass_inventories, :gate_pass_id
    add_index :gate_pass_inventories, :client_category_id
  end
end