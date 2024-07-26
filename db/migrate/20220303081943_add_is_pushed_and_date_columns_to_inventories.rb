class AddIsPushedAndDateColumnsToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :is_pushed, :boolean, default: false 
    add_column :inventories, :pushed_at, :datetime
    add_column :inventories, :synced_at, :datetime
  end
end
