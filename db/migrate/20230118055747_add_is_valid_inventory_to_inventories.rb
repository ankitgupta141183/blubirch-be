class AddIsValidInventoryToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :is_valid_inventory, :boolean, :default => true
  end
end
