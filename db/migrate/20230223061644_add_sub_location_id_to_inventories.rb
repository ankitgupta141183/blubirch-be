class AddSubLocationIdToInventories < ActiveRecord::Migration[6.0]
  def change
    add_column :inventories, :sub_location_id, :integer
    add_column :inventories, :is_putaway_inwarded, :boolean
  end
end
