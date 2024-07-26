class AddGatepassInventoryIdToInventories < ActiveRecord::Migration[6.0]
  def change
  	add_column :inventories, :gate_pass_inventory_id, :integer
  	add_index :inventories, :gate_pass_inventory_id
  end
end
