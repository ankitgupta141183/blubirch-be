class AddInventoriesIsSynced < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :is_synced, :boolean, default: false
    add_column :inventories, :imei1, :string
    add_column :inventories, :imei2, :string
  end
end
